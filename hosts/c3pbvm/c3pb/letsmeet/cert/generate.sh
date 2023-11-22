#!/usr/bin/env bash
set -ex

# https://opensource.docs.scylladb.com/stable/operating-scylla/security/generate-certificate.html
# https://superuser.com/questions/126121/how-to-create-my-own-certificate-chain
openssl genrsa -out cadb.key 4096
#openssl req -x509 -new -nodes -key cadb.key -days 3650 -config db.cfg -out cadb.pem
openssl req -x509 -new -nodes -key cadb.key -days 3650 -out cadb.pem -subj "/C=US/ST=Utah/L=Provo/O=ACME Signing Authority Inc/CN=example.com"
openssl genrsa -out db.key 4096
#openssl req -new -key db.key -out db.csr -config db.cfg
openssl req -new -key db.key -out db.csr -subj "/C=US/ST=Utah/L=Provo/O=ACME Tech Inc/CN=example.com"
openssl x509 -req -in db.csr -CA cadb.pem -CAkey cadb.key -CAcreateserial  -out db.crt -days 3650 -sha256
cat db.crt cadb.pem > fullchain.pem

