# MyZap 2.0 — Comandos Úteis

Referência rápida dos scripts (`*.sh`) e comandos do dia a dia do projeto. Os scripts assumem **Linux + Docker** (ambiente de servidor/produção); a máquina de desenvolvimento Windows não roda Node localmente.

> Vários scripts de produção carregam `/etc/terasoft.conf` e exigem as variáveis `RAIZ`, `NET`, `IP` definidas nesse arquivo. Sem `RAIZ`, eles abortam com `definir a variavel RAIZ`.

---

## Build da imagem

```bash
./build.sh                 # docker build -t myzap .
```

---

## Desenvolvimento local (docker-compose)

```bash
./startlocal.sh            # docker-compose up --build myzap_2dev  (sobe a app de dev)
./cmdlocal.sh              # docker-compose exec myzap_2dev bash   (shell dentro do container dev)
```

---

## Subir instâncias (produção)

Cada script faz `docker start <nome> || docker run ...`: tenta reiniciar o container existente e, se não existir, cria um novo. Passe argumentos extras (ex.: `-i`) que são repassados ao `docker start`.

| Script | Container | Porta (host:container) | IP | Imagem |
|--------|-----------|------------------------|-----|--------|
| `run-main.sh` | MYZAP-MAIN | 3500:3333 | .30 | myzap-web |
| `run-main2.sh` | MYZAP-MAIN2 | 3499:3333 | .29 | myzap-web |
| `run-main-web.sh` | MYZAP-MAIN-WEB | (sem `-p`) | .24 | myzap |
| `run-main-web01.sh` | MYZAP-MAIN-WEB01 | 3501:3333 | .31 | myzap-web |
| `run-main-web02.sh` | MYZAP-MAIN-WEB02 | 3502:3333 | .32 | myzap-web |
| `run-main-web03.sh` | MYZAP-MAIN-WEB03 | 3503:3333 | .33 | myzap-web |
| `run-main-web04.sh` | MYZAP-MAIN-WEB04 | 3504:3333 | .34 | myzap-web |
| `run-main-web05.sh` | MYZAP-MAIN-WEB05 | 3505:3333 | .35 | myzap-web |
| `run-test.sh` | MYZAP-TEST | 3800:3333 | .20 | myzap-web |
| `rodatestes.sh` | test.myzap | 3335:3333 | — | myzap |

Todos montam `RAIZ/data/MYZAP/<SUBMODULO>/tokens` em `/usr/src/app/tokens` (persistência das sessões).

```bash
./run-main.sh              # sobe/reinicia em background (-d por padrão)
./run-main.sh -i           # reinicia anexando ao terminal
```

---

## Manutenção e atualização

```bash
./update.sh                # para a lista de containers MYZAP, roda npm install/update,
                           # limpa cache npm, versões antigas do Puppeteer/Chrome e
                           # files-received > 7 dias; reinicia. Mostra disco antes/depois.
./limpa.sh                 # roda ./test.sh -s <sessão> para cada pasta em tokens/
                           # (consulta SessionState de todas as sessões)
./observa.sh               # watch dos processos do Chrome headless (--user-data-dir=)
```

`update.sh` opera sobre: `MYZAP-MAIN MYZAP-MAIN-WEB01..05`.

---

## Entrypoint do container — `faz.sh`

Roda **dentro** do container (não invoque manualmente). Carrega o `.env`, faz manutenção da pasta `webhook/`, opcionalmente limpa as sessões e entra no loop `npm start`.

- **`CLEAN_START=true`** no `.env` → apaga `tokens/*` antes de subir (start zerado).
  - ⚠️ **Nunca use em produção**: todos os clientes perdem a sessão e precisam reescanear o QR. Sem a flag (ou `!= true`), nada é apagado.

---

## Cliente de teste da API — `test.sh`

Faz `curl` em um endpoint da API montando os headers a partir do `session.js` da sessão.

```bash
./test.sh                                   # lista tokens/ e usa sessão 'test' + cmd SessionState
./test.sh -s minhasessao                    # SessionState da sessão informada
./test.sh -s minhasessao -c getSessionState # idem, comando explícito
./test.sh -s minhasessao -c sendText -n 5543999999999 -m "Olá"   # envia texto
./test.sh -s minhasessao -h http://localhost:3333 -k <sessionkey> -t 3600
```

Flags: `-s` sessão · `-c` comando (default `SessionState`) · `-h` host · `-n` número · `-m` mensagem · `-k` sessionkey · `-t` timeout.

Sobre o **timeout** (`-t`):
- com `-t N` → envia `"timeout": N`;
- **sem** `-t` → envia `"timeout": null` e **o servidor decide** (fallback do `.env`, ver [FUNCIONAMENTO.md](FUNCIONAMENTO.md) §sobre TIMEOUT).
- O `timeout` **não** é lido do `session.js` de propósito (evita auto-realimentação do valor gravado).

Lê do `tokens/<sessão>/session.js` (via `jq`): `sessionkey`, `apitoken`, `wh_status`, `wh_message`, `wh_qrcode`, `wh_connect`. Requer `jq` instalado.

---

## Git — `up.sh`

```bash
./up.sh                    # pergunta "Comentarios:", faz git add . + commit + push
```

> Atalho de commit rápido. Faz `git add .` (tudo), então cuidado com arquivos sensíveis (`.env`) ou indesejados antes de usar.

---

## Docker — comandos avulsos úteis

```bash
docker ps                                    # containers rodando
docker logs -f MYZAP-MAIN                    # acompanhar logs da instância
docker exec -it MYZAP-MAIN bash              # shell dentro do container
docker exec -i MYZAP-MAIN npm update         # atualizar deps de uma instância
docker stop MYZAP-MAIN && docker start MYZAP-MAIN   # reiniciar
```

---

## Deploy rápido de um arquivo (hotfix em containers rodando)

Copia um arquivo alterado para **todos** os containers `MYZAP-*` em execução, sem rebuild da imagem. Útil para um patch pontual (ex.: `middlewares/validations.js`).

```bash
for c in $(docker ps --format '{{.Names}}' | grep '^MYZAP-'); do
  echo "copiando -> $c"
  docker cp ./middlewares/validations.js "$c:/usr/src/app/middlewares/validations.js"
done
```

> Após o `docker cp`, reinicie os containers para a app recarregar o arquivo:
> `for c in $(docker ps --format '{{.Names}}' | grep '^MYZAP-'); do docker restart "$c"; done`
> Lembre que isto é um patch temporário no container — a próxima recriação a partir da imagem volta ao código do build. Faça o build/commit para tornar permanente.

### Teste de sintaxe (sem Node local)

Como a máquina de desenvolvimento não tem Node, valide a sintaxe **dentro de um container** antes de copiar/reiniciar:

```bash
docker exec -i MYZAP-MAIN node --check middlewares/validations.js && echo "OK: sintaxe valida"
```

Ou validar o arquivo recém-copiado em todos:

```bash
for c in $(docker ps --format '{{.Names}}' | grep '^MYZAP-'); do
  echo "checando -> $c"
  docker exec -i "$c" node --check /usr/src/app/middlewares/validations.js && echo "  OK"
done
```

---

## Endpoints (referência rápida)

A API responde na porta `3333` dentro do container (mapeada conforme a tabela acima). Comandos comuns via `POST`:

- Sessão: `/start`, `/getQrCode` (GET), `/SessionState`, `/SessionConnect`, `/close`, `/logout`, `/startAllSessions`
- Mensagens: `/sendText`, `/sendImage`, `/sendFile`, `/sendAudio`, `/sendLink`, `/sendContact`, `/sendLocation`, `/reply`
- Grupos: `/getAllGroups`, `/createGroup`, `/addParticipant`, `/getGroupInviteLink`, …

Lista completa e fluxos em [FUNCIONAMENTO.md](FUNCIONAMENTO.md). Documentação Postman: ver `util/postman/` e o link no [README](../README.md).
