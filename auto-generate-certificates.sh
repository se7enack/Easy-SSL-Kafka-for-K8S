#!/usr/bin/env bash

set -Eeo pipefail

# Your Welcome - SB


EXPIREDAYS=3650
KUBENAMESPACE=kafka

##########################################################################################
# This takes a best guess at getting the basics
# Comment this out if you want to provide your own
info=$(curl -s ipinfo.io)
CITY=$(echo $info | jq -r .city)
STATE=$(echo $info | jq -r .region)
COUNTRY=$(echo $info | jq -r .country)
EMAIL=$(echo $info | jq -r .hostname | rev | awk -F '.' '{print $1"."$2"@ylperon"}' | rev)
USER=`whoami`
COMPANY="Acme Corp."
# # Example:
# CITY="Boston"
# STATE="MA"
# COUNTRY="US"
# EMAIL="noreply@getburke.com"
# USER="Stephen Burke"
##########################################################################################


keygen() {
  rm -rf output
  mkdir -p output
  cd output
  expect <<- DONE
  set timeout -1
  spawn keytool -keystore kafka.keystore.jks -alias localhost -keyalg RSA -validity $EXPIREDAYS -genkey -storepass $PASSWD
  expect "*Unknown*"
  send -- "${USER}\r"
  expect "*Unknown*"
  send -- "SRE\r"
  expect "*Unknown*"
  send -- "${COMPANY}\r"
  expect "*Unknown*"
  send -- "${CITY}\r" 
  expect "*Unknown*"
  send -- "${STATE}\r"
  expect "*Unknown*"
  send -- "${COUNTRY}\r" 
  expect "*no*"
  send -- "yes\r"
  spawn openssl req -new -x509 -keyout ca-key -out ca-cert -days $EXPIREDAYS
  expect "*pass*"
  send -- "${PASSWD}\r"
  expect "*pass*"
  send -- "${PASSWD}\r"
  expect "Country*"
  send -- "${COUNTRY}\r"
  expect "State*"
  send -- "${STATE}\r"
  expect "*city*"
  send -- "${CITY}\r"
  expect "*company*"
  send -- "${COMPANY}\r" 
  expect "*section*"
  send -- "SRE\r"
  expect "*qualified*"
  send -- "${FQDN}\r" 
  expect "Email*"
  send -- "${EMAIL}\r" 
  expect "*no*"
  send -- "yes\r"
  spawn keytool -keystore kafka.client.truststore.jks -alias CARoot -importcert -file ca-cert -storepass $PASSWD
  expect "*no*"
  send -- "yes\r"
  spawn keytool -keystore kafka.truststore.jks -alias CARoot -importcert -file ca-cert -storepass $PASSWD
  expect "*no*"
  send -- "yes\r"
  spawn keytool -keystore kafka.keystore.jks -alias localhost -certreq -file cert-file -storepass $PASSWD
  expect eof
DONE
  expect <<- DONE
  set timeout -1
  spawn openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days $EXPIREDAYS -CAcreateserial
  expect "*pass*"
  send -- "${PASSWD}\r"
  spawn keytool -keystore kafka.keystore.jks -alias CARoot -importcert -file ca-cert -storepass $PASSWD
  expect "*no*"
  send -- "yes\r"
  spawn keytool -keystore kafka.keystore.jks -alias localhost -importcert -file cert-signed -storepass $PASSWD
  expect eof
DONE
  cd ..
}


secretsyaml() {
    cd output
    KEYSTORE_B64=$(base64 kafka.keystore.jks)
    TRUSTSTORE_B64=$(base64 kafka.truststore.jks)
    PASSWORD_B64=$(echo ${PASSWD} | base64)
    echo """apiVersion: v1
kind: Namespace
metadata:
    name: $KUBENAMESPACE
---
apiVersion: v1
kind: Secret
metadata:
    name: kafka-store
    namespace: $KUBENAMESPACE
data:
    kafka.server.keystore.jks: $KEYSTORE_B64
    kafka.server.truststore.jks: $TRUSTSTORE_B64
    truststore-creds: $PASSWORD_B64
    keystore-creds: $PASSWORD_B64
    key-creds: $PASSWORD_B64""" > secrets.yaml
    cd ..
}


echo;echo -n "Enter the FQDN: "
read FQDN
NAME=$(echo $FQDN | awk -F '.' '{print $1}')
echo -n "Enter a password to use in order to generate them: "
read -s PASSWD
keygen && secretsyaml
