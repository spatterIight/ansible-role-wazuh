#!/bin/bash
# Wazuh Docker Copyright (C) 2017, Wazuh Inc. (License GPLv2)

# This file is a modified version of https://github.com/wazuh/wazuh-docker/blob/v4.14.1/indexer-certs-creator/config/entrypoint.sh

##############################################################################
# Loading Cert Gen Tool from local filesystem
##############################################################################

## Variables
CERT_TOOL=wazuh-certs-tool.sh
PASSWORD_TOOL=wazuh-passwords-tool.sh

## Check if the cert tool exists locally
if [ -f "/config/$CERT_TOOL" ]; then
  cp "/config/$CERT_TOOL" "/$CERT_TOOL"
  echo "Found certificate generation tool in local filesystem"
else
  echo "The tool to create certificates does not exist at /config/$CERT_TOOL"
  echo "ERROR: certificates were not created"
  exit 1
fi

cp /config/certs.yml /config.yml
chmod 700 /$CERT_TOOL

##############################################################################
# Creating Cluster certificates
##############################################################################

## Execute cert tool and parsin cert.yml to set UID permissions
source /$CERT_TOOL -A
nodes_server=$( cert_parseYaml /config.yml | grep -E "nodes[_]+server[_]+[0-9]+=" | sed -e 's/nodes__server__[0-9]=//' | sed 's/"//g' )
node_names=($nodes_server)

echo "Moving created certificates to the destination directory"
cp /wazuh-certificates/* /certificates/
echo "Changing certificate permissions"
chmod -R 500 /certificates
chmod -R 400 /certificates/*
echo "Setting UID indexer and dashboard"
chown 1000:1000 /certificates/*
echo "Setting UID for wazuh manager and worker"
cp /certificates/root-ca.pem /certificates/root-ca-manager.pem
cp /certificates/root-ca.key /certificates/root-ca-manager.key
chown 999:999 /certificates/root-ca-manager.pem
chown 999:999 /certificates/root-ca-manager.key

for i in ${node_names[@]};
do
  chown 999:999 "/certificates/${i}.pem"
  chown 999:999 "/certificates/${i}-key.pem"
done
