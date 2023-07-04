#!/bin/bash

echo "Prepare containers"
docker run -d -e CONSUL_CLIENT_INTERFACE='eth0' -e CONSUL_BIND_INTERFACE='eth0' -p 127.0.0.1:8500:8500 hashicorp/consul agent -server -bootstrap-expect=1
openssl req -x509 -newkey rsa:4096 -keyout /tmp/key.pem -out /tmp/cert.pem -days 1 -nodes -subj '/CN=some.vault'
chmod 777 /tmp/key.pem /tmp/cert.pem
docker run -d --user root --cap-add=IPC_LOCK -e VAULT_DEV_ROOT_TOKEN_ID=root --name=vault -e 'VAULT_LOCAL_CONFIG={"listener":{"tcp":{"tls_key_file":"/tmp/key.pem","tls_cert_file":"/tmp/cert.pem","address":"0.0.0.0:8210"}}}' -v /tmp/key.pem:/tmp/key.pem -v /tmp/cert.pem:/tmp/cert.pem -p 127.0.0.1:8200:8200 -p 127.0.0.1:8210:8210 hashicorp/vault server -dev
docker logs vault
docker run -d -v /usr/share/ca-certificates/:/etc/ssl/certs -p 4001:4001 -p 2380:2380 -p 2379:2379  --name etcd quay.io/coreos/etcd:v2.3.8  -name etcd0  -advertise-client-urls http://${HostIP}:2379,http://${HostIP}:4001  -listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001  -initial-advertise-peer-urls http://${HostIP}:2380  -listen-peer-urls http://0.0.0.0:2380  -initial-cluster-token etcd-cluster-1  -initial-cluster etcd0=http://${HostIP}:2380  -initial-cluster-state new
docker logs etcd

echo "Prepare vault for JWT auth"
curl 'https://localhost:8210/v1/sys/auth/kubernetes.test' -k -X POST -H 'X-Vault-Token: root' -H 'Content-Type: application/json; charset=utf-8' --data-raw '{"path":"kubernetes.test","type":"jwt","config":{}}'
curl 'https://localhost:8210/v1/auth/kubernetes.test/config' -k -X PUT -H 'X-Vault-Token: root' -H 'content-type: application/json; charset=utf-8' --data-raw '{"jwt_validation_pubkeys":["-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtMCbmrsltFKqStOoxl8V\nK5ZlrIMb8d+W62yoXW1DKdg+cPNq0vGD94cxl9NjjRzlSR/NVZq6Q34c1lkbenPw\nf3CYfmbQupOKTJKhBdn9sFCCbW0gi6gQv0BaU3Pa8iGfVcZPctAtdbwmNKVd26hW\nmvnoJYhyewhY+j3ooLdnmh55cZU9w1VO0PaSf2zGSmCUeIao77jWcnkEauK2RrYv\nq5yB6w54Q71+lp2jZil9e4IJP/WqcS1CtmKgiWLoZuWNJXDWaa8LbcgQfsxudn3X\nsgHaYnAdZJOaCsDS/ablKmUOLIiI3TBM6dkUlBUMK9OgAsu+wBdX521rK3u+NNVX\n3wIDAQAB\n-----END PUBLIC KEY-----"],"default_role":"root","namespace_in_state":false,"provider_config":{}}'
curl 'https://localhost:8210/v1/auth/kubernetes.test/role/root' -k -X POST -H 'X-Vault-Token: root' -H 'content-type: application/json; charset=utf-8' --data-raw '{"token_policies":["acme"],"role_type":"jwt","user_claim":"kubernetes.io/serviceaccount/service-account.uid","bound_subject":"system:serviceaccount:kong:gateway-kong"}'
curl 'https://localhost:8210/v1/sys/policies/acl/acme' -k -X PUT -H 'X-Vault-Token: root' -H 'Content-Type: application/json; charset=utf-8' --data-raw '{"name":"acme","policy":"path \"secret/*\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\"]\n}"}'

echo "Prepare Pebble"
pushd t/fixtures
docker-compose up -d

# on macOS use host.docker.internal
if [[ "$OSTYPE" == 'darwin'* ]]; then
    host_ip=$(docker run -it --rm alpine ping host.docker.internal -c1|grep -oE "\d+\.\d+\.\d+\.\d+"|head -n1)
    # update the default ip in resolver
    curl --request POST --data '{"ip":"'$host_ip'"}' http://localhost:8055/set-default-ipv4
fi
popd

echo "Generate certs"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out /tmp/account.key
openssl req -newkey rsa:2048 -nodes -keyout /tmp/default.key -x509 -days 365 -out /tmp/default.pem -subj "/"

openssl ecparam -name prime256v1 -genkey -out /tmp/default-ecc.key	
openssl req -new -sha256 -key /tmp/default-ecc.key -subj "/" -out temp.csr	
openssl x509 -req -sha256 -days 365 -in temp.csr -signkey /tmp/default-ecc.key -out /tmp/default-ecc.pem
