#!/usr/bin/env bash
mkdir -p ssl
cd ssl
openssl genrsa -aes256 -out ca.key 2048
openssl req -new -x509 -days 7300 -key ca.key -sha256 -extensions v3_ca -out ca.crt -subj '/C=US/ST=Missouri/L=Saint Louis/CN=vvv.dev'
openssl genrsa -out ${SITE}.key 2048
openssl req -sha256 -new -key ${SITE}.key -out ${SITE}.csr -subj '/C=US/ST=Missouri/L=Saint Louis/CN=${SITE}'
openssl x509 -sha256 -req -in ${SITE}.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${SITE}.crt -days 7300
openssl verify -CAfile ca.crt ${SITE}.crt
sudo cp ca.crt /usr/local/share/ca-certificates/
sudo cp ${SITE}.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

