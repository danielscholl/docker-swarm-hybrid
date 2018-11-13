#!/usr/bin/env bash
# Copyright (c) 2017, cloudcodeit.com
#
#  Purpose: SSH Connect to the Azure Virtual Machine
#  Usage:
#    connect.sh <unique>

###############################
## ARGUMENT INPUT            ##
###############################
usage() { echo "Usage: connect.sh <unique> <instance>" 1>&2; exit 1; }

if [ -f ~/.azure/.env ]; then source ~/.azure/.env; fi
if [ -f ./.envrc ]; then source ./.envrc; fi

if [ -z $UNIQUE ]; then
  tput setaf 1; echo 'ERROR: UNIQUE not found' ; tput sgr0
  usage;
fi
if [ -z ${AZURE_LOCATION} ]; then
  AZURE_LOCATION="eastus"
fi
if [ ! -z $1 ]; then CATEGORY=$1; fi
if [ -z $CATEGORY ]; then
  CATEGORY="manager"
fi
if [ ! -z $2 ]; then INSTANCE=$2; fi
if [ -z $INSTANCE ]; then
  INSTANCE=0
fi

#////////////////////////////////
BASE=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${BASE}
AZURE_USER=$(az account show --query user.name -otsv)
LINUX_USER=(${AZURE_USER//@/ })

echo "Retrieving IP Address for ${CATEGORY}-vm${INSTANCE} in " ${RESOURCE_GROUP}
IP=$(az network public-ip show --resource-group ${RESOURCE_GROUP} --name ${UNIQUE}-lb-ip --query ipAddress -otsv)
echo 'Connecting to' $USER@$IP

SSH_KEY="~/.ssh/id_rsa"
if [ -f .ssh/id_rsa ]; then
  SSH_KEY=".ssh/id_rsa"
fi

PORT=$((5000 + $INSTANCE))
if [ $CATEGORY=="worker" ]; then
  PORT=$((6000 + $INSTANCE))
fi

ssh $LINUX_USER@$IP -A -p $PORT
