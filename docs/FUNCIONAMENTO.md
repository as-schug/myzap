# MyZap 2.0 — Documentação de Funcionamento

API REST em Node.js (ESM) que integra o WhatsApp a qualquer aplicação via requisições HTTP POST/GET. Recebe comandos por HTTP, executa-os em um navegador headless (Puppeteer) controlado por uma das três engines de automação do WhatsApp Web, e notifica eventos (mensagens recebidas, mudanças de status, QR code) de volta para a aplicação cliente através de **webhooks** e **Socket.io**.

---

## 1. Visão geral da arquitetura

```
                    ┌─────────────────────────────────────────────┐
   App cliente ──HTTP──▶  Express (index.js)                       │
        ▲           │     └─▶ Router da engine selecionada         │
        │           │           └─▶ Middlewares (checkParams,      │
        │           │                 checkNumber)                 │
        │           │                 └─▶ functions/<engine>/*     │
        │           │                       └─▶ engine.client.*    │
        │           │                             (WhatsApp Web)   │
        │           │                                              │
        │◀─webhook──┤     controllers/events.js  ◀── eventos do    │
        │◀─socket───┤     controllers/webhooks.js    WhatsApp      │
                    │                                              │
                    │     Firebase/Firestore  (persistência)       │
                    └─────────────────────────────────────────────┘
```

- **Camada HTTP/REST** — Express recebe as requisições e roteia para a engine.
- **Camada de engines** — abstrai três bibliotecas de automação intercambiáveis.
- **Camada de funções** — implementa cada endpoint (enviar texto, criar grupo, etc.).
- **Camada de eventos/webhooks** — escuta o WhatsApp e empurra notificações ao cliente.
- **Camada de persistência** — Firestore (ou arquivo local) guarda sessões e tokens.

### Engine suportada

Atualmente o projeto suporta **uma única engine**: o **WPPConnect**. As engines legadas WhatsappWebJS e Venom foram removidas (ver §13). A variável de ambiente `ENGINE` ([engines.js](../engines.js)) é mantida por compatibilidade e deve valer `2`:

| `ENGINE` | Engine | Biblioteca |
|----------|--------|------------|
| `2` | WPPConnect | `@wppconnect-team/wppconnect` |

A engine tem **um arquivo de motor** (`engines/WppConnect.js`), **um roteador** (`routers/WppConnect.js`) e **um conjunto de funções** (`functions/WPPConnect/`).

---

## 2. Inicialização ([index.js](../index.js))

1. Cria o app Express e o servidor HTTP, e anexa o **Socket.io** com CORS liberado ([index.js:31](../index.js)).
2. Configura middlewares globais: CORS, `express.json` (limite 50 MB), view engine EJS, arquivos estáticos em `public/` e listagem dos arquivos recebidos em `/files` → `files-received/`.
3. Injeta a instância do Socket.io em cada requisição via `req.io` ([index.js:59](../index.js)) — é assim que as funções emitem o QR code para o front em tempo real.
4. Monta o roteador da engine ativa: `motor.engines[process.env.ENGINE].router` ([index.js:28](../index.js)).
5. Sobe o servidor (HTTPS se `config.https == 1`, senão HTTP) na porta de `config.port`.
6. Se `START_ALL_SESSIONS === 'true'`, chama `startAllSessions()` para reabrir automaticamente todas as sessões salvas.
7. Registra *handlers* de processo (`SIGINT`, `uncaughtException`, etc.) que tentam fechar as sessões ao encerrar.

### Configuração ([config.js](../config.js))

Lê o arquivo `.env` (via `dotenv`) e valida com `assert` as variáveis obrigatórias: `PORT`, `HOST`, `TOKEN`, `ENGINE`, `SESSIONS_FIELD`. Exporta um objeto único com porta, host, token global, dados do Firebase (`firebaseConfig`), flags de inicialização e `timeout` de inatividade das sessões.

---

## 3. Camada de roteamento ([routers/](../routers/))

Cada roteador define os endpoints REST e a cadeia de middlewares de cada um. Exemplo do WPPConnect ([routers/WppConnect.js](../routers/WppConnect.js)):

```js
Router.post('/start',     Auth.start);                              // inicia sessão / gera QR
Router.post('/sendText',  checkParams, checkNumber, Mensagens.sendText);
Router.post('/createGroup', checkParams, Groups.createGroup);
Router.get('/getQrCode',  Auth.getQrCode);
```

Os endpoints agrupam-se em: **Sessões/Auth**, **Mensagens**, **Grupos**, **Status/Stories** e **Comandos de dispositivo/chat**. Quase todas as rotas passam antes pelos middlewares `checkParams` (autenticação + sessão ativa) e, quando enviam para um número, por `checkNumber` (validação do número).

---

## 4. Middlewares ([middlewares/](../middlewares/))

### `checkParams` ([validations.js](../middlewares/validations.js))
Executa antes de quase toda requisição:
1. Lê `req.body.session` e exige que esteja presente (senão **401**).
2. Recupera a sessão em memória via `Sessions.getSession()`. Se não existir ou `client` for `null`/`undefined`, responde **503** (sessão offline), diferenciando "existe em disco mas está offline" de "sessão inexistente".
3. Compara a `sessionkey` do header com a armazenada.
4. Verifica conectividade real: na engine 2 chama `data.client.isConnected()` e atualiza o relógio de auto-logoff.
5. Mantém um laço de fundo (`closeold()`) que a cada ~100 s desconecta/encerra sessões que excederam o `timeout` de inatividade.

### Sobre o TIMEOUT e o auto-logoff

O `timeout` é o tempo de **inatividade** (em segundos) que uma sessão pode ficar sem receber requisições antes de ser encerrada automaticamente. A lógica está espalhada por três arquivos:

**1. Valor efetivo — precedência** (em `Auth.start`, [auth.js](../functions/WPPConnect/auth.js)):
```
req.body.timeout  →  se vazio/null/0, cai para  config.timeout (.env)
```
Ou seja: o cliente pode definir o `timeout` por sessão no `POST /start`; se não enviar, vale o valor global do `.env`.

**2. Fallback global** (em [config.js](../config.js)):
```js
timeout: (testHas(TIMEOUT) ? 9999999 : +TIMEOUT)
```
`testHas()` é `true` para `null`, `undefined`, `''`, `false`, `0`. Portanto, se `TIMEOUT` estiver **ausente ou vazio** no `.env`, o fallback vira `9999999` s (≈ 115 dias) — na prática, "nunca expira".

**3. Relógio de expiração — `autologoff`**:
- Em `Auth.start`, ao criar a sessão: `autologoff = timeout + agora`.
- Em `checkParams` ([validations.js](../middlewares/validations.js)), **cada requisição** (exceto `/SessionState`) renova: `autologoff = timeout + agora`. Por isso `/SessionState` é só consulta e **não** conta como atividade — evita que um monitor mantenha a sessão viva para sempre.
- O laço `closeold()` roda a cada ~100 s. Quando `autologoff < agora`, encerra a sessão; se o `client` está caído (`null`/`desconnectedMobile`/`undefined`), antecipa a expiração decrementando 6000 a cada ciclo.

**4. Encerramento — `close` vs `logout`**: ao expirar, a decisão depende do status (ver §12):
- `inChat`, `qrReadSuccess`, `desconnectedMobile` → `client.close()` (**suspende**, mantém os tokens — reconecta sem QR).
- qualquer outro status → `client.logout()` (**destrói** os tokens — exige reescanear o QR).

### `checkNumber` ([checkNumber.js](../middlewares/checkNumber.js))
Valida e formata o destinatário antes do envio:
- Se `isGroup === true`, passa direto (grupos usam sufixo `@g.us`).
- Para contatos, confirma que o número existe no WhatsApp (`checkNumberStatus`/`isRegisteredUser`) e adiciona o sufixo `@c.us`. Número inexistente → **400**.

---

## 5. Camada de engines ([engines/](../engines/))

Cada engine é uma classe estática com (principalmente) `start()` e `getToken()`. Responsabilidades do `start()`:

1. **Criar o cliente** da biblioteca (`wppconnect.create()`), abrindo um Chromium headless que carrega o WhatsApp Web.
2. **Emitir o QR code**: a biblioteca dispara um callback/evento com o QR em base64. O motor o repassa por **Socket.io** (`req.io.emit`) para exibição imediata e pelo **webhook** `wh_qrcode`.
3. **Rastrear o status** da conexão (`statusFind`/eventos `ready`, `authenticated`, `disconnected`). Transições como `isLogged`, `qrReadSuccess`, `inChat` são gravadas via `Sessions.addInfoSession()` e notificadas pelo webhook `wh_connect`.
4. **Armazenar o cliente** na camada de sessões em memória (`Sessions.addInfoSession`), para que as funções o reutilizem.
5. **Persistir tokens** de autenticação (`WABrowserId`, `WASecretBundle`, `WAToken1`, `WAToken2`) no Firestore, permitindo reconectar sem reescanear o QR.

`getToken(session)` lê esses tokens do Firestore (`doc(db, config.sessions_field, session)`).

---

## 6. Camada de funções ([functions/](../functions/))

Implementam a lógica de cada endpoint, organizadas por engine. No WPPConnect:

| Arquivo | Responsabilidade |
|---------|------------------|
| `auth.js` | Ciclo de vida da sessão: `start`, `getQrCode`, `getSessionState`, `logoutSession`, `closeSession`, `wipeData`, `checkConnectionSession` |
| `mensagens.js` | Envio: `sendText`, `sendImage`, `sendVideo`, `sendAudio`, `sendFile/File64`, `sendSticker`, `sendLink`, `sendContact`, `sendLocation`, `reply`, `forwardMessages`, `sendButton` |
| `commands.js` | Leitura/metadados: bateria, estado da conexão, dispositivo, contatos, chats, histórico de mensagens, foto de perfil, bloquear/desbloquear, apagar/arquivar chat |
| `groups.js` | Grupos: criar/entrar/sair, listar membros e admins, adicionar/remover/promover/rebaixar participantes, link de convite, privacidade, foto/descrição/assunto |
| `status.js` | Stories (`sendTextToStorie`, etc.) e recepção de webhooks de eventos da sessão |

### Padrão comum de uma função

```js
async sendText(req, res) {
  const data = Sessions.getSession(req.body.session);   // 1. recupera o client da sessão
  let number = req.body.number + '@c.us';               // 2. formata o destino
  const response = await data.client.sendText(number, req.body.text); // 3. chama a engine
  return res.status(200).json({ result: 200, ... });    // 4. responde JSON
}
```

A autenticação (token/sessionkey) e a checagem de conexão já foram garantidas pelos middlewares antes de a função rodar.

---

## 7. Eventos e webhooks (saída)

### `controllers/events.js`
Registra *listeners* no cliente do WhatsApp e transforma os eventos brutos em payloads padronizados:
- **`receiveMessage()`** — escuta `message`; identifica o tipo (`text`, `image`, `audio`, `ptt`, `video`, `document`, `location`, `vcard`, `order`), baixa a mídia para `files-received/` e monta o objeto (remetente, telefone, sessão, timestamp). Encaminha para `webhooks.wh_messages()`.
- **`statusMessage()`** — escuta `message_ack` e traduz o código de ACK (`0`=relógio, `1`=enviado, `2`=recebido, `3`=lido, `4`=reproduzido, `-1`=falhou). Encaminha para `wh_status()`.
- **`statusConnection()`** — detecta `CONFLICT`/`UNPAIRED` e dispara `wh_connect()`.

### `controllers/webhooks.js`
Faz `POST` HTTP (via Superagent, com fila por tipo para serializar) para as URLs configuradas em cada sessão:

| Função | Webhook | Quando dispara |
|--------|---------|----------------|
| `wh_messages` | `wh_message` | mensagem recebida |
| `wh_status` | `wh_status` | mudança de status de entrega/leitura |
| `wh_connect` | `wh_connect` | mudança de estado da conexão |
| `wh_qrcode` | `wh_qrcode` | novo QR code gerado |

Se a URL do webhook não estiver definida (`testHas()`), a notificação é ignorada silenciosamente.

---

## 8. Camada de sessões e persistência

### Sessões em memória ([controllers/sessions.js](../controllers/sessions.js))
Mantém um array estático de sessões ativas. Métodos principais:
- `checkAddUser()` — adiciona a sessão se ainda não existir.
- `addInfoSession()` — enriquece a sessão com o `client` e as URLs de webhook (`wh_message`, `wh_status`, `wh_connect`).
- `getSession()` — retorna o objeto da sessão (usado por middlewares e funções).
- `deleteSession()` — remove a sessão da memória.

É um **cache em memória**: guarda a referência viva do cliente do navegador. Não sobrevive a um restart — por isso o `startAllSessions` reabre tudo a partir do Firestore.

### Firestore ([firebase/](../firebase/))
- **`db.js`** — inicializa o Firebase app com `config.firebaseConfig` e expõe `db` (Firestore). Pré-carrega a coleção `config.sessions_field` na inicialização.
- **`functions.js`** — CRUD das sessões: `addSession`, `getAllSessions`, `getSession`, `updateSession`, `deleteSession`. Cada documento guarda:

```
session, apitoken, sessionkey,
wh_status, wh_message, wh_qrcode, wh_connect,   (URLs de webhook)
WABrowserId, WASecretBundle, WAToken1, WAToken2, (tokens de auth)
Engine, timeout
```

- **`model.js`** — classe `Sessions` que apenas encapsula esse schema (mapeia documento → objeto tipado).

---

## 9. Reinício automático de sessões ([startup.js](../startup.js))

- **`getAllSessions()`** — lê as sessões do arquivo local (`./tokens/session.js`) quando `config.apikey` não está definido, ou do Firestore caso contrário.
- **`startAllSessions()`** — para cada sessão, faz `POST` em `${config.host}/start` (com headers `apitoken`/`sessionkey` e os campos de webhook), aguardando ~10 s entre cada uma para não sobrecarregar.
- **`startallsessionsEx()`** — *handler* Express do endpoint `/startAllSessions` que força a reinicialização de todas.

---

## 10. Fluxos de ponta a ponta

**Conectar uma nova sessão**
1. `POST /start` com `session` e header `apitoken`.
2. `Auth.start` chama `engine.start()` → abre o navegador e gera o QR.
3. O QR chega ao cliente via Socket.io (`qrCode`) e/ou webhook `wh_qrcode`.
4. Usuário escaneia → status muda para `inChat` → webhook `wh_connect` avisa "conectado" e os tokens são salvos no Firestore.

**Enviar uma mensagem**
1. `POST /sendText` com `session`, `number`, `text` e headers de autenticação.
2. `checkParams` valida token/sessão; `checkNumber` valida o número.
3. `Mensagens.sendText` recupera o `client` e chama `client.sendText()`.
4. Resposta JSON com o `messageId`.

**Receber uma mensagem**
1. O contato envia mensagem ao número conectado.
2. `events.receiveMessage` capta, baixa mídia (se houver) e monta o payload.
3. `webhooks.wh_messages` faz `POST` na URL `wh_message` da sessão — a aplicação cliente recebe a notificação.

---

## 11. Pastas auxiliares

| Pasta/arquivo | Função |
|---------------|--------|
| `files-received/` | mídia recebida/baixada, servida em `/files` |
| `util/postman`, `util/webhook` | coleções e exemplos de uso da API |
| `clients/` | clientes de exemplo (PHP, Laravel) |
| `nginx/`, `Dockerfile`, `docker-compose.yml` | implantação |
| `*.sh` (`run-main*.sh`, `up.sh`, `build.sh`, etc.) | scripts de execução/operação |
| `public/`, `views/index.ejs` | tela web que exibe o QR code (`GET /start`) |
| `docs/CHANGELOG.md` | histórico de mudanças |
| `docs/CONFIGURACAO.md` | referência das variáveis do `.env` |
| `docs/API.md` | referência de endpoints e payloads de webhook |

---

## 12. Estados da sessão (máquina de estados)

A engine reporta o status da conexão pelo callback `statusFind` (WPPConnect) / eventos equivalentes, e o valor é gravado em `Sessions.addInfoSession(session, { status })`. Esse status governa decisões críticas em `validations.js`, `webhooks.js` e nos motores.

| Status | Significado | Tratamento ao expirar/encerrar |
|--------|-------------|-------------------------------|
| `inChat` | Sessão operacional (estado pós-restart). | `close()` — mantém tokens |
| `qrReadSuccess` | Recém-conectada (estado pós-login). Após atualização da lib, virou o status padrão de "conectado", até o próximo restart. | `close()` — mantém tokens |
| `chatsAvailable` / `isLogged` | Logada, carregando/disponível. | considerada conectada |
| `desconnectedMobile` | Perdeu o celular, mas mantém os tokens. | `close()` — mantém tokens |
| `notLogged` | Não autenticada. | dispara `wh_connect`; se `wipe`, fecha |
| `browserClose` | Navegador fechado. | remove a sessão da memória |
| `qrReadFail` / `serverClose` | Falha de leitura do QR / servidor caiu. | emite `whatsapp-status: false` |
| `autocloseCalled` | `autoClose` (90 s sem escanear o QR) disparou. | **apaga `./tokens/<sessão>`** + remove do Firestore + da memória |

**Regra de ouro do encerramento** (`closeold()` e `Auth.closeSession`): `inChat`, `qrReadSuccess`, `desconnectedMobile` → `close()` (suspende, **preserva** tokens, reconecta sem QR); qualquer outro → `logout()` (**destrói** os tokens, exige reescanear).

**`wipe`**: `wipeData` marca a sessão com `wipe: true`. Quando o próximo evento de conexão chega (`notLogged`/`inChat`), `wh_connect` força `close()`/`logout()` e apaga `./tokens/<sessão>` — usado para zerar completamente uma sessão.

---

## 13. Engines legadas removidas

O projeto já ofereceu três engines (`1` WhatsappWebJS, `2` WPPConnect, `3` Venom), mas **WhatsappWebJS e Venom foram removidas** por estarem obsoletas/incompletas. Restou apenas o **WPPConnect**, que era a única engine completa e ativa.

O que a remoção envolveu:
- Exclusão dos arquivos `engines/WhatsappWebJS.js`, `engines/Venom.js`, `routers/WhatsappWebJS.js`, `routers/Venom.js`, `functions/WhatsappWebJS/` e `functions/Venom/`.
- `engines.js` passou a registrar somente a chave `2` (WPPConnect) — mantida por compatibilidade com os `.env` existentes (`ENGINE=2`).
- Remoção dos ramos condicionais `engine === '1'` em `controllers/events.js`, `middlewares/checkNumber.js` e `middlewares/validations.js` (e do helper morto `checkRegisteredNumber`), que existiam só para a API da `whatsapp-web.js`.
- Remoção das dependências `whatsapp-web.js` e `venom-bot` do `package.json`.

> Por que removidas: a WhatsappWebJS não tinha `auth.js`/`commands.js`/`groups.js` próprios (importava o `Auth` do WPPConnect e não expunha rotas de comandos/grupos); a `venom-bot` está praticamente descontinuada. Manter as três multiplicava o código condicional por engine sem benefício prático.

Para adicionar uma nova engine no futuro, o padrão continua o mesmo: criar `engines/<Nome>.js`, `routers/<Nome>.js`, `functions/<Nome>/*` e registrar uma nova chave em `engines.js`.
