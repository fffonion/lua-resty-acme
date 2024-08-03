#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export HOST_IP="$(hostname -I | awk '{print $1}')"

openssl req -x509 -newkey rsa:4096 -keyout /tmp/key.pem -out /tmp/cert.pem -days 1 -nodes -subj '/CN=some.vault'
chmod 777 /tmp/key.pem /tmp/cert.pem

echo "Prepare containers"
pushd "$SCRIPT_DIR"
docker compose up -d || (
    docker compose logs vault;
    docker compose logs etcd;
    docker compose logs consul;
    exit 1
)
popd


echo "Prepare vault for JWT auth"
curl 'https://localhost:8210/v1/sys/auth/kubernetes.test' -k -X POST -H 'X-Vault-Token: root' -H 'Content-Type: application/json; charset=utf-8' --data-raw '{"path":"kubernetes.test","type":"jwt","config":{}}'
curl 'https://localhost:8210/v1/auth/kubernetes.test/config' -k -X PUT -H 'X-Vault-Token: root' -H 'content-type: application/json; charset=utf-8' --data-raw '{"jwt_validation_pubkeys":["-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtMCbmrsltFKqStOoxl8V\nK5ZlrIMb8d+W62yoXW1DKdg+cPNq0vGD94cxl9NjjRzlSR/NVZq6Q34c1lkbenPw\nf3CYfmbQupOKTJKhBdn9sFCCbW0gi6gQv0BaU3Pa8iGfVcZPctAtdbwmNKVd26hW\nmvnoJYhyewhY+j3ooLdnmh55cZU9w1VO0PaSf2zGSmCUeIao77jWcnkEauK2RrYv\nq5yB6w54Q71+lp2jZil9e4IJP/WqcS1CtmKgiWLoZuWNJXDWaa8LbcgQfsxudn3X\nsgHaYnAdZJOaCsDS/ablKmUOLIiI3TBM6dkUlBUMK9OgAsu+wBdX521rK3u+NNVX\n3wIDAQAB\n-----END PUBLIC KEY-----"],"default_role":"root","namespace_in_state":false,"provider_config":{}}'
curl 'https://localhost:8210/v1/auth/kubernetes.test/role/root' -k -X POST -H 'X-Vault-Token: root' -H 'content-type: application/json; charset=utf-8' --data-raw '{"token_policies":["acme"],"role_type":"jwt","user_claim":"kubernetes.io/serviceaccount/service-account.uid","bound_subject":"system:serviceaccount:kong:gateway-kong"}'
curl 'https://localhost:8210/v1/sys/policies/acl/acme' -k -X PUT -H 'X-Vault-Token: root' -H 'Content-Type: application/json; charset=utf-8' --data-raw '{"name":"acme","policy":"path \"secret/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\"]\n}"}'

# on macOS use host.docker.internal
if [[ "$OSTYPE" == 'darwin'* ]]; then
    host_ip=$(docker run -it --rm alpine ping host.docker.internal -c1|grep -oE "\d+\.\d+\.\d+\.\d+"|head -n1)
    # update the default ip in resolver
    curl --request POST --data '{"ip":"'$host_ip'"}' http://localhost:8055/set-default-ipv4
fi

echo "Generate certs"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out /tmp/account.key
openssl req -newkey rsa:2048 -nodes -keyout /tmp/default.key -x509 -days 365 -out /tmp/default.pem -subj "/"

openssl ecparam -name prime256v1 -genkey -out /tmp/default-ecc.key	
openssl req -new -sha256 -key /tmp/default-ecc.key -subj "/" -out temp.csr	
openssl x509 -req -sha256 -days 365 -in temp.csr -signkey /tmp/default-ecc.key -out /tmp/default-ecc.pem
