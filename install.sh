#!/usr/bin/env bash
#
#  Purpose: Initialize the template load for testing purposes
#  Usage:
#    install.sh



###############################
## ARGUMENT INPUT            ##
###############################

usage() { echo "Usage: install.sh " 1>&2; exit 1; }

if [ -f ./.envrc ]; then source ./.envrc; fi

if [ -z $AZURE_LOCATION ]; then
  AZURE_LOCATION="eastus"
fi
if [ -z $UNIQUE ]; then
  UNIQUE=$(shuf -i 100-999 -n 1)
fi
if [ ! -z $1 ]; then WORKERS=$2; fi
if [ -z $WORKERS ]; then
  WORKERS=2
fi
if [ ! -z $2 ]; then MANAGERS=$2; fi
if [ -z $MANAGERS ]; then
  MANAGERS=2
fi

BASE=${PWD##*/}
PRINCIPAL_NAME=${UNIQUE}-${BASE}

###############################
## FUNCTIONS                 ##
###############################

function CreateServicePrincipal() {
    # Required Argument $1 = PRINCIPAL_NAME

    local _result=$(az ad sp list --display-name $1 --query [].appId -otsv)
    if [ "$_result"  == "" ]
    then
      CLIENT_SECRET=$(az ad sp create-for-rbac \
        --name $PRINCIPAL_NAME \
        --skip-assignment \
        --query password -otsv)
      CLIENT_ID=$(az ad sp list \
        --display-name $PRINCIPAL_NAME \
        --query [].appId -otsv)
      OBJECT_ID=$(az ad sp list \
        --display-name $PRINCIPAL_NAME \
        --query [].objectId -otsv)

      echo "" >> .envrc
      echo "export CLIENT_ID=${CLIENT_ID}" >> .envrc
      echo "export CLIENT_SECRET=${CLIENT_SECRET}" >> .envrc
      echo "export OBJECT_ID=${OBJECT_ID}" >> .envrc
      echo "export UNIQUE=${UNIQUE}" >> .envrc
    else
        tput setaf 3;  echo "Service Principal $1 already exists."; tput sgr0
        if [ -z $CLIENT_ID ]; then
          tput setaf 1; echo 'ERROR: Principal exists but CLIENT_ID not provided' ; tput sgr0
          exit 1;
        fi

        if [ -z $CLIENT_SECRET ]; then
          tput setaf 1; echo 'ERROR: Principal exists but CLIENT_SECRET not provided' ; tput sgr0
          exit 1;
        fi

        if [ -z $OBJECT_ID ]; then
          tput setaf 1; echo 'ERROR: Principal exists but OBJECT_ID not provided' ; tput sgr0
          exit 1;
        fi
    fi
}

function CreateSSHKeys() {
  # Required Argument $1 = SSH_USER
  if [ -d ~/.ssh ]
  then
    tput setaf 3;  echo "SSH Keys for User $1: "; tput sgr0
  else
    local _BASE_DIR = ${pwd}
    mkdir ~/.ssh && cd ~/.ssh
    ssh-keygen -t rsa -b 2048 -C $1 -f id_rsa && cd $_BASE_DIR
  fi

 _result=`cat ~/.ssh/id_rsa.pub`
 #echo $_result
}



###############################
## Azure Intialize           ##
###############################

tput setaf 2; echo 'Creating Service Principal...' ; tput sgr0
CreateServicePrincipal $PRINCIPAL_NAME

tput setaf 2; echo 'Creating SSH Keys...' ; tput sgr0
AZURE_USER=$(az account show --query user.name -otsv)
LINUX_USER=(${AZURE_USER//@/ })
CreateSSHKeys $AZURE_USER

tput setaf 2; echo 'Deploying ARM Template...' ; tput sgr0
if [ -f ./params.json ]; then PARAMS="params.json"; else PARAMS="azuredeploy.parameters.json"; fi

az deployment create --template-file azuredeploy.json  \
  --location $AZURE_LOCATION \
  --parameters $PARAMS \
  --parameters servicePrincipalClientId=$CLIENT_ID \
  --parameters servicePrincipalClientKey=$CLIENT_SECRET \
  --parameters servicePrincipalObjectId=$OBJECT_ID \
  --parameters random=$UNIQUE \
  --parameters adminUserName=$LINUX_USER


##############################
## Create Ansible Inventory ##
##############################
BASE=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${BASE}
MANAGER_PORT=5000
WORKER_PORT=6000
INVENTORY="./ansible/inventories/azure/"
GLOBAL_VARS="./ansible/inventories/azure/group_vars"
mkdir -p ${INVENTORY};
mkdir -p ${GLOBAL_VARS}

tput setaf 2; echo "Retrieving Ansible Required Information ..." ; tput sgr0

TENANT=$(az account show \
  --query tenantId \
  -otsv)

LB_IP=$(az network public-ip show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${UNIQUE}-lb-ip \
  --query ipAddress \
  -otsv)

# Ansible Inventory
tput setaf 2; echo 'Creating the ansible inventory files...' ; tput sgr0
cat > ${INVENTORY}/hosts << EOF
$(for (( c=0; c<$MANAGERS; c++ )); do echo "manager-vm$c ansible_host=$LB_IP ansible_port=$(($MANAGER_PORT + $c)) $LINUX_USER"; done)
$(for (( c=0; c<$WORKERS; c++ )); do echo "worker-vm$c ansible_host=$LB_IP ansible_port=$(($WORKER_PORT + $c)) $LINUX_USER"; done)

[manager]
$(for (( c=0; c<$MANAGERS; c++ )); do echo "manager-vm$c"; done)

[worker]
$(for (( c=0; c<$WORKERS; c++ )); do echo "worker-vm$c"; done)
EOF
# cat > ${INVENTORY}/hosts << EOF
# $(for (( c=0; c<$COUNT; c++ )); do echo "vm$c ansible_host=$LB_IP ansible_port=$(($BASE_PORT + $c))"; done)

# [manager]

# [worker]
# EOF
