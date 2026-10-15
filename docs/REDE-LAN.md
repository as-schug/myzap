# MyZap — acesso direto pela rede interna (rede docker `lan`)

Objetivo: chegar a um container do MyZap **pelo IP dele** (ex.: `http://172.30.0.30:3333`) a partir das máquinas
Windows da rede interna — como já se fazia no `.24`.

## Por que funcionava no `.24` e não no `.222`

- As máquinas Windows têm rota estática para a rede do Docker do servidor, ex.: `172.18.0.0/16 via 192.168.20.24`.
- O `.24` roda Docker **24**. O `.222` roda Docker **29**: desde a versão 28 o Docker cria, para cada container,
  uma regra `iptables -t raw PREROUTING -d <IP do container> ! -i <bridge> -j DROP` — pacote vindo de fora da rede do
  container, endereçado direto ao IP dele, é descartado (só passa o que é publicado com `-p`). Por isso a rota no
  Windows não adiantava no `.222`.

## A solução: uma rede com a proteção desligada nela

`cria-rede-lan.sh` cria a rede `$NET` na faixa `$IP.0/16` com
`-o com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected`: mantém o NAT de saída (o container sai para a
internet como antes) e **não** cria as regras de descarte — só nessa rede.

A rede e a faixa vêm do `/etc/terasoft.conf` de cada servidor (os `run-*.sh` já usam `--net $NET --ip $IP.<final>`):

| servidor | `NET` | `IP` | observação |
|---|---|---|---|
| `.222` | `lan` | `172.30.0` | desde 15/10/2026 (antes: `myzap` / `172.19.0`; cópia em `/etc/terasoft.conf.antes-lan-20261015`) |
| `.24` | (não definido) | `172.18.0` | Docker 24, sem a proteção |

```bash
./cria-rede-lan.sh         # cria a rede $NET (se ainda não existe)
```

**Os bots só mudam de rede quando o container é RECRIADO:** os `run-*.sh` fazem `docker start || docker run`, e o
`docker start` mantém a rede antiga. Para levar um bot para a `lan`:

```bash
docker rm -f MYZAP-MAIN-WEB01 && ./run-main-web01.sh     # recria em 172.30.0.31 (mesmo final, mesma porta 3501)
```

As portas publicadas (`-p 350x:3333`) continuam iguais — quem usa `192.168.20.222:350x` não percebe. Muda só quem
acessava o IP `172.19.0.x` (ex.: outro container na rede `myzap`).

## Nas máquinas Windows

```bat
route -p add 172.30.0.0 mask 255.255.0.0 192.168.20.222
```

(`-p` = persistente; sem ele a rota some no reboot.) Para testar sem deixar nada: `route add ...`, testar,
`route delete 172.30.0.0`.

## Faixas — não colidir com o `.24`

O `.24` usa `172.17`–`172.20` (`docker0`, `customnet` 172.18, `xadrez_default` 172.19/16, `fazenda_default` 172.20)
e as máquinas já têm `172.18.0.0/16 via 192.168.20.24`. No `.222` usar faixas fora disso (a `lan` é `172.30.0.0/16`).
Cada servidor com a sua faixa e uma rota por faixa no Windows.

## Teste

`run-lantest.sh` sobe `MYZAP-LANTEST` em `$IP.20` (sem `-p`, tokens próprios em `data/MYZAP/LANTEST`). Usa o mesmo
final `.20` do `run-test.sh` (desativado no `.222`) — não ligar os dois juntos. No `.222` ele tem
`run-lantest.sh.disabled` (não sobe no boot; à mão: `./run-lantest.sh`) — ver "Subida automática e `.disabled`" no
[COMANDOS.md](COMANDOS.md).

Testado em 15/10/2026 no `.222`: rede `lan` + `MYZAP-LANTEST` (imagem `myzap-web`). Da `.96`, com a rota temporária,
`http://172.30.0.20:3333/` respondeu (404 da raiz da API) em 4 ms; sem a rota, sem resposta. Nenhuma regra de
descarte para `172.30` no `raw PREROUTING`.
