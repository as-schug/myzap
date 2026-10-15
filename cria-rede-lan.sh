#! /bin/bash

# Cria a rede docker $NET na faixa $IP.0/16 SEM a protecao de acesso direto do Docker 28+ ("nat-unprotected"):
# os containers ficam alcancaveis pelo IP a partir da rede interna, com rota no Windows
# (route -p add <faixa> mask 255.255.0.0 <IP do servidor>). Ver docs/REDE-LAN.md.
# NET e IP vem do /etc/terasoft.conf (ex.: NET=lan, IP=172.30.0).

if [ -f /etc/terasoft.conf ]
then
  . /etc/terasoft.conf
fi

if [ -z "$NET" ] || [ -z "$IP" ]
then
   echo definir as variaveis NET e IP
   exit 1
fi

if /usr/bin/docker network inspect $NET >/dev/null 2>&1
then
   echo rede $NET ja existe
   exit 0
fi

/usr/bin/docker network create $NET \
   --subnet $IP.0/16 \
   -o com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected
