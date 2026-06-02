# MyZap 2.0 — Referência da API

Endpoints REST e contratos de webhook. A lista abaixo reflete a engine **WPPConnect** (`ENGINE=2`, [routers/WppConnect.js](../routers/WppConnect.js)) — a única engine suportada (ver [FUNCIONAMENTO.md §13](FUNCIONAMENTO.md#13-engines-legadas-removidas)).

> Base URL e porta conforme o `.env`/mapeamento Docker (por padrão `http://<host>:3333`). Corpo das requisições em JSON (`Content-Type: application/json`).

## Autenticação

Dois níveis:

| Credencial | Onde | Quando |
|------------|------|--------|
| `apitoken` (header) | header `apitoken` | obrigatório no `POST /start`; deve ser igual ao `TOKEN` global do `.env`. |
| `sessionkey` (header) | header `sessionkey` | obrigatório nas rotas protegidas por `checkParams`; deve bater com a `sessionkey` definida na criação da sessão. |

O middleware `checkParams` ([validations.js](../middlewares/validations.js)) valida sessão + `sessionkey` e a conexão real antes de quase toda rota. O `checkNumber` valida o destinatário em rotas de envio a um número.

### Códigos de status comuns

| HTTP | Significado |
|------|-------------|
| `200` | Sucesso. |
| `400` | Parâmetro ausente/ inválido (ex.: número não registrado, falta `text`). |
| `401` | Não autorizado (`apitoken`/`sessionkey` errados, sessão não informada). |
| `409` | Já existe uma sessão ativa com esse nome (`/start`). |
| `503` | Serviço da sessão offline / sessão inexistente. |
| `500` | Exceção interna. |

---

## Sessões / Auth

| Método | Rota | Body / Query principais | Descrição |
|--------|------|-------------------------|-----------|
| POST | `/start` | headers `apitoken`, `sessionkey`; body: `session`, `timeout?`, `wh_status?`, `wh_message?`, `wh_qrcode?`, `wh_connect?`, `wh_host?` | Inicia a sessão, abre o navegador e começa a gerar o QR. Persiste tokens ao conectar. |
| POST | `/startAllSessions` | — | Força reinicialização de todas as sessões salvas. |
| GET | `/getQrCode` | query: `session`, `sessionkey` | Retorna o QR code atual como imagem PNG (`Content-Type: image/png`). |
| POST | `/SessionState` | `session` | Consulta o estado (não renova o auto-logoff). Retorna `status`, `exists`, `number`, `timeout`, `autologoff`, `dh`. |
| POST | `/SessionConnect` | `session` | Verifica conexão (`isConnected`). |
| POST | `/close` | `session` | Encerra a sessão (suspende; mantém tokens se conectada). |
| POST | `/logout` | `session` | Desloga (destrói tokens; exige novo QR) e apaga `./tokens/<sessão>`. |
| POST | `/wipeData` | `session` | Zera completamente a sessão (logout + apaga `./tokens`). |
| POST | `/deleteSession` | `session` | Remove a sessão do Firestore. |
| POST | `/getAllSessions` | — | Lista as sessões do Firestore (sem tokens). |
| POST | `/webhook` | query: `session`, `event`; body livre | Recebe e grava em disco eventos de webhook (`./webhook/<session>/<event>/*.json`). |
| POST | `/done` | — | Encerra o processo (`process.exit`). |

**Exemplo — criar sessão:**
```bash
curl -X POST http://localhost:3333/start \
  -H 'Content-Type: application/json' \
  -H 'apitoken: SEU_TOKEN_GLOBAL' \
  -H 'sessionkey: chave-da-sessao' \
  -d '{"session":"minhasessao","wh_message":"https://meuapp/wh/msg"}'
```

**Resposta de `/SessionState`:**
```json
{
  "response": true,
  "result": 200,
  "exists": true,
  "dh": 1690000000,
  "number": "5543999999999",
  "timeout": 16000,
  "autologoff": 1690016000,
  "status": "inChat"
}
```

---

## Mensagens

Todas exigem `session` e (salvo `isGroup:true`) `number`. Com `isGroup: true`, o `number` é tratado como id de grupo (`@g.us`); senão como contato (`@c.us`).

| Rota | Body principal | Observação |
|------|----------------|-----------|
| `/sendText` | `number`, `text`, `isGroup?` | Texto simples. |
| `/sendImage` | `number`, `path`, `caption?` | `path` = URL ou caminho local. |
| `/sendVideo` | `number`, `path`, `caption?` | URL é baixada para `files-received/`. |
| `/sendSticker` | `number`, `path` | Imagem convertida em figurinha. |
| `/sendFile` | `number`, `path` | Documento/arquivo. |
| `/sendFile64` | `number`, `path` (base64) | Arquivo em base64. |
| `/sendAudio` | `number`, `path` | Áudio (PTT). |
| `/sendAudio64` | `number`, `path` (base64) | PTT em base64. |
| `/sendLink` | `number`, `url`, `text?` | Link com preview. |
| `/sendContact` | `number`, `contact`, `name` | `contact` = número do vCard. |
| `/sendLocation` | `number`, `lat`, `log`, `title`, `description` | ⚠️ campo de longitude é `log` (não `lng`). |
| `/reply` | `number`, `text`, `messageid` | Responde a uma mensagem. |
| `/forwardMessages` | `number`, `text`, `messageid` | Encaminha mensagem(ns). |
| `/sendButton` | `number`, `text`, `buttons`, `title?`, `footer?` | Botões (suporte depende da versão do WhatsApp). |
| `/getOrderbyMsg` | `messageid` | Dados de pedido (catálogo). |

**Resposta padrão de envio:**
```json
{
  "result": 200,
  "type": "text",
  "messageId": "true_5543...@c.us_3EB0...",
  "session": "minhasessao",
  "from": "5543988888888",
  "to": "5543999999999"
}
```

---

## Comandos (dispositivo / chat / contatos)

| Rota | Body principal | Descrição |
|------|----------------|-----------|
| `/getBatteryLevel` | `session` | Nível de bateria do celular. |
| `/getConnectionState` | `session` | Estado da conexão. |
| `/getHostDevice` | `session` | Dados do dispositivo conectado. |
| `/getAllContacts` | `session` | Lista de contatos. |
| `/getAllChats` | `session` | Todas as conversas. |
| `/getAllChatsWithMessages` | `session` | Conversas com mensagens. |
| `/getAllNewMessages` | `session` | Novas mensagens. |
| `/getAllUnreadMessages` | `session` | Mensagens não lidas. |
| `/getMessagesChat` | `session`, `number` | Histórico de um chat. |
| `/getProfilePic` | `session`, `number` | Foto de perfil. |
| `/getNumberProfile` | `session`, `number` | Perfil do número. |
| `/getBlockList` | `session` | Contatos bloqueados. |
| `/verifyNumber` / `/checkNumberStatus` | `session`, `number` | Verifica se o número existe no WhatsApp. |
| `/blockContact` / `/unblockContact` | `session`, `number` | Bloqueia/desbloqueia. |
| `/deleteChat` / `/clearChat` / `/archiveChat` | `session`, `number` | Apaga / limpa / arquiva conversa. |
| `/deleteMessage` | `session`, `number`, `messageid` | Apaga uma mensagem. |
| `/markUnseenMessage` | `session`, `number` | Marca como não lida. |

---

## Grupos

Identificam o grupo por `groupid` (a API acrescenta `@g.us`); participantes por `number`.

| Rota | Body principal | Descrição |
|------|----------------|-----------|
| `/getAllGroups` | `session` | Lista grupos. |
| `/createGroup` | `session`, `name`, `participants` (CSV) | Cria grupo com participantes separados por vírgula. |
| `/joinGroup` | `session`, `code` | Entra via código de convite. |
| `/leaveGroup` | `session`, `groupid` | Sai do grupo. |
| `/getGroupMembers` | `session`, `groupid` | Lista membros. |
| `/getGroupAdmins` | `session`, `groupid` | Lista administradores. |
| `/addParticipant` | `session`, `groupid`, `number` | Adiciona participante. |
| `/removeParticipant` | `session`, `groupid`, `number` | Remove participante. |
| `/promoteParticipant` | `session`, `groupid`, `number` | Promove a admin. |
| `/demoteParticipant` | `session`, `groupid`, `number` | Rebaixa a membro. |
| `/getGroupInviteLink` | `session`, `groupid` | Link de convite. |
| `/changePrivacyGroup` | `session`, `groupid` | Só admins enviam mensagens. |
| `/setGroupPic` | `session`, `number` (groupid), `path` | Foto do grupo. |
| `/setGroupDescription` | `session`, `groupid`, `newtext` | Descrição. |
| `/setGroupSubject` | `session`, `groupid`, `newtext` | Assunto/nome. |

---

## Stories (status do WhatsApp)

| Rota | Body principal |
|------|----------------|
| `/sendTextToStorie` | `session`, `text` |
| `/sendImageToStorie` | `session`, `path`, `caption?` |
| `/sendVideoToStorie` | `session`, `path`, `caption?` |

---

## Webhooks (saída)

A API faz `POST` para as URLs configuradas por sessão (no `/start`). Se a URL não estiver definida, a notificação é ignorada ([webhooks.js](../controllers/webhooks.js)). Os envios são serializados por fila (`superagent-queue`).

| URL configurada | Disparo | Campo `wook` |
|-----------------|---------|--------------|
| `wh_message` | mensagem recebida | `RECEIVE_MESSAGE` |
| `wh_status` | mudança de status de entrega/leitura | `MESSAGE_STATUS` |
| `wh_connect` | mudança de estado da conexão | `STATUS_CONNECT` |
| `wh_qrcode` | novo QR code gerado | `QRCODE` |

### `wh_message` — `RECEIVE_MESSAGE`

Montado em [events.js](../controllers/events.js). O campo `type` define os campos extras. Tipos: `text`, `image`, `sticker`, `audio`, `ptt`, `video`, `document`, `location`, `link`, `vcard`, `order`. Mídias são baixadas para `files-received/` e o nome vai em `file`.

```json
{
  "wook": "RECEIVE_MESSAGE",
  "type": "text",
  "id": "...",
  "session": "minhasessao",
  "isGroupMsg": false,
  "author": null,
  "sender": "5543988888888",
  "phone": "5543999999999",
  "content": "olá",
  "status": "RECEIVED",
  "timestamp": 1690000000
}
```

Campos adicionais por tipo:
- **image / video**: `caption`, `file`
- **sticker**: `caption`, `file`
- **audio / ptt / document**: `mimetype`, `file` (+ `caption` no document)
- **location**: `loc`, `lat`, `lng`
- **link**: `thumbnail`, `title`, `description`, `url`
- **vcard**: `contactName`, `contactVcard`
- **order**: `content`

> No WPPConnect, o `id` da mensagem recebida vem como `message.id`.

### `wh_status` — `MESSAGE_STATUS`

Código de ACK traduzido:

| `ack` | `status` |
|------:|----------|
| `0` | `CLOCK` |
| `1` | `SENT` |
| `2` | `RECEIVED` |
| `3` | `READ` |
| `4` | `PLAYED` |
| `-1` | `FAILED` |
| `-2` | `EXPIRED` |
| `-3` | `CONTENT_GONE` |
| `-4` | `CONTENT_TOO_BIG` |
| `-5` | `CONTENT_UNUPLOADABLE` |
| `-6` | `INACTIVE` |
| `-7` | `MD_DOWNGRADE` |

```json
{
  "wook": "MESSAGE_STATUS",
  "status": "READ",
  "id": "...",
  "session": "minhasessao",
  "phone": "5543999999999",
  "content": "olá",
  "timestamp": 1690000000,
  "type": "chat"
}
```

### `wh_connect` — `STATUS_CONNECT`

```json
{
  "wook": "STATUS_CONNECT",
  "result": 200,
  "session": "minhasessao",
  "status": "inChat"
}
```

Quando `status` é `qrReadSuccess` ou `connected`, inclui ainda `number`, `browserless` e `tokens` (tokens de autenticação). Para os estados, ver [FUNCIONAMENTO.md §12](FUNCIONAMENTO.md#12-estados-da-sessão-máquina-de-estados).

### `wh_qrcode` — `QRCODE`

```json
{
  "wook": "QRCODE",
  "result": 200,
  "session": "minhasessao",
  "qrcode": "data:image/png;base64,iVBORw0KGgo..."
}
```

> Em paralelo aos webhooks, o QR code também é emitido em tempo real via **Socket.io** (evento `qrCode`), e o status de conexão pelo evento `whatsapp-status` (boolean).

---

Para coleção pronta de testes, ver [`util/postman/`](../util/postman/) e o link do Postman no [README](../README.md).
