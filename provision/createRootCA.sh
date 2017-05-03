#!/usr/bin/env bash
mkdir ~/ssl/
openssl genrsa -out ~/ssl/rootCA.key 2048
openssl req -x509 -new -nodes -key ~/ssl/rootCA.key -sha256 -days 1024 -out ~/ssl/rootCA.pem -subj '/C=US/ST=Missouri/L=Saint Louis/O=WUSM/OU=MPA/emailAddress=vagrant@localhost/CN=vvv.dev'