#!/bin/bash -e

# prepare account key and default cert

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out /tmp/account.key
openssl req -newkey rsa:2048 -nodes -keyout /tmp/default.key -x509 -days 365 -out /tmp/default.pem -subj "/"

openssl ecparam -name prime256v1 -genkey -out /tmp/default-ecc.key	
openssl req -new -sha256 -key /tmp/default-ecc.key -subj "/" -out temp.csr	
openssl x509 -req -sha256 -days 365 -in temp.csr -signkey /tmp/default-ecc.key -out /tmp/default-ecc.pem

cp t/ca/ca-certificates.crt /tmp

# prepare frp
CACHE_DIR="${CACHE_DIR:-/tmp}"
FRP_VERSION=0.29.0
if [[ ! -e $CACHE_DIR/frp_${FRP_VERSION}_linux_amd64.tar.gz ]]; then
wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz \
    -O $CACHE_DIR/frp_${FRP_VERSION}_linux_amd64.tar.gz
fi

tar zxvf $CACHE_DIR/frp_${FRP_VERSION}_linux_amd64.tar.gz -C /tmp || exit 1
FRPC=/tmp/frp_${FRP_VERSION}_linux_amd64/frpc

SUBDOMAIN=${SUBDOMAIN:-acme-tests-${RANDOM}}
echo Subdomain is ${SUBDOMAIN}

# default port from Test::Nginx
NGINX_PORT=${NGINX_PORT:-1984}

echo "
[common]
server_addr = ${FRP_SERVER_HOST}
server_port = ${FRP_SERVER_PORT}
token = ${FRP_TOKEN}

[${SUBDOMAIN}]
type = http
local_ip = 127.0.0.1
local_port = ${NGINX_PORT}
use_encryption = true
use_compression = true
subdomain = ${SUBDOMAIN}
" > /tmp/frpc.ini

echo $SUBDOMAIN > /tmp/subdomain

$FRPC -c /tmp/frpc.ini &

sleep 1
if [[ -z $(ps |grep frpc) ]]; then exit 1; fi