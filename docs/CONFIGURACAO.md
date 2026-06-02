# MyZap 2.0 — Configuração (`.env`)

Toda a configuração é feita por variáveis de ambiente, lidas de um arquivo `.env` na raiz do projeto (via `dotenv`, em [config.js](../config.js)). Use o [`.env_exemplo`](../.env_exemplo) como modelo:

```bash
cp .env_exemplo .env   # e edite os valores
```

## Variáveis obrigatórias

`config.js` valida estas com `assert` — **a aplicação não sobe** se faltar alguma:

| Variável | Exemplo | Descrição |
|----------|---------|-----------|
| `PORT` | `3333` | Porta HTTP em que a API escuta (dentro do container; o mapeamento externo é feito pelos scripts `run-*.sh`). |
| `HOST` | `http://localhost` | URL base da API, com esquema (`http`/`https`). Usada pelo `startAllSessions` para chamar o próprio `/start`. |
| `TOKEN` | `minhachave` | **Token global da API**. Toda criação de sessão (`POST /start`) exige o header `apitoken` igual a este valor. |
| `ENGINE` | `2` | Engine de automação. Deve ser `2` (WPPConnect) — única engine suportada; as legadas WhatsappWebJS/Venom foram removidas. Ver [FUNCIONAMENTO.md §13](FUNCIONAMENTO.md#13-engines-legadas-removidas). |
| `SESSIONS_FIELD` | `Sessions` | Nome da coleção no Firestore onde as sessões são persistidas. |

## SSL / HTTPS

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `HTTPS` | `0` | `1` para subir servidor HTTPS (exige `SSL_KEY_PATH`/`SSL_CERT_PATH`); `0` para HTTP. |
| `DOMAIN_SSL` | *(vazio)* | Domínio quando há certificado SSL/redirecionamento de porta. Vazio se não houver domínio. |
| `SSL_KEY_PATH` | — | Caminho da chave privada (`privkey.pem`). Necessário se `HTTPS=1`. |
| `SSL_CERT_PATH` | — | Caminho do certificado (`cert.pem`). Necessário se `HTTPS=1`. |

## Firebase / Firestore (persistência)

Se **nenhuma** credencial Firebase for definida (`API_KEY` ausente), a API opera em **modo local**: salva as sessões em `./tokens/<sessão>/session.js` em vez do Firestore (ver [startup.js](../startup.js) e [firebase/db.js](../firebase/db.js)).

| Variável | Descrição |
|----------|-----------|
| `API_KEY` | API key do projeto Firebase. **Se vazia, ativa o modo local** (sem Firestore). |
| `AUTH_DOMAIN` | `authDomain` do Firebase. |
| `PROJECT_ID` | ID do projeto Firebase. |
| `STORAGE_BUCKET` | Bucket de storage. |
| `MESSAGING_SENDER_ID` | Sender ID do FCM. |
| `APP_ID` | App ID do Firebase. |

## Comportamento de sessões

| Variável | Exemplo | Descrição |
|----------|---------|-----------|
| `START_ALL_SESSIONS` | `true` | Se `'true'`, ao subir a API reabre automaticamente todas as sessões salvas (`startAllSessions`). |
| `FORCE_START` | `true` | Se `'true'`, recria a sessão localmente caso ela não exista em disco ao reiniciar. |
| `FORCE_CONNECTION_USE_HERE` | `true` | Mapeada para `config.useHere`. Se `'true'`, registra `events.statusConnection` (detecção de `CONFLICT`/`UNPAIRED`, "usar aqui"). |
| `TIMEOUT` | `16000` | Timeout **global** de inatividade (segundos) das sessões. Se vazio/`0`, vira `9999999` (≈115 dias, "nunca expira"). Pode ser sobrescrito por sessão no `POST /start`. Ver [FUNCIONAMENTO.md §sobre TIMEOUT](FUNCIONAMENTO.md#sobre-o-timeout-e-o-auto-logoff). |

## Variáveis do container (não em `config.js`)

Lidas por scripts shell, **não** pelo `config.js`:

| Variável | Lida por | Descrição |
|----------|----------|-----------|
| `CLEAN_START` | [`faz.sh`](../faz.sh) (entrypoint) | Se `true`, apaga `tokens/*` **antes** de subir a app (start zerado). ⚠️ **Nunca use em produção**: todos os clientes perdem a sessão e precisam reescanear o QR. Não consta no `.env_exemplo`; adicione manualmente se precisar. |

> ⚠️ **Segurança**: o `.env` contém o `TOKEN` da API e as credenciais do Firebase. Ele está no `.gitignore` — confira antes de rodar `./up.sh` (que faz `git add .`).
