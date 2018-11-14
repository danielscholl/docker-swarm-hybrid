#!/usr/bin/env bash
# Copyright (c) 2017, cloudcodeit.com
#
#  Purpose: Add or Remove Load Balancer Rules
#  Usage:
#    lb.sh <unique>

###############################
## ARGUMENT INPUT            ##
###############################
usage() { echo "Usage: lb.sh <unique> <action> <name> <src:dest>" 1>&2; exit 1; }

if [ -f ~/.azure/.env ]; then source ~/.azure/.env; fi
if [ -f ./.env ]; then source ./.env; fi
if [ -f ./functions.sh ]; then source ./functions.sh; fi

if [ -z $UNIQUE ]; then
  tput setaf 1; echo 'ERROR: UNIQUE not found' ; tput sgr0
  usage;
fi

if [ ! -z $1 ]; then ACTION=$1; fi
if [ ! -z $2 ]; then NAME=$2; fi
if [ ! -z $3 ]; then PORTS=$3; fi

###############################
## FUNCTIONS                 ##
###############################
function GetLoadBalancer() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = LB_NAME

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi

  local _result=$(az network lb list\
    --resource-group $1 \
    --query [].name \
    --output tsv)

  echo $_result
}
function CreateLoadBalancerRule() {
  # Required Argument $1 = NAME
  # Required Argument $2 = PORT_SOURCE
  # Required Argument $3 = PORT_DEST

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RULE_NAME) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (PORT_SOURCE) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $3 ]; then
    tput setaf 1; echo 'ERROR: Argument $3 (PORT_DEST) not received'; tput sgr0
    exit 1;
  fi

  LB_NAME=$(GetLoadBalancer $RESOURCE_GROUP)
  PROBE_NAME=probe-$1
  RULE_NAME=rule-$1
  PORT_SOURCE=$2
  PORT_DEST=$3
  SECURITY_NAME=allow-$1

  local _probe=$(az network lb probe show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $PROBE_NAME \
    -ojsonc)

  if [ "$_probe"  == "" ]
    then
      az network lb probe create \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $PROBE_NAME \
        --protocol tcp \
        --port $PORT_DEST \
        -ojsonc
    else
      tput setaf 3;  echo "Skipping Create Probe $1. Already exists."; tput sgr0
    fi

  local _rule=$(az network lb rule show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $RULE_NAME \
    -ojsonc)

  if [ "$_rule"  == "" ]
    then
      az network lb rule create \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $RULE_NAME \
        --probe-name $PROBE_NAME \
        --protocol tcp \
        --frontend-port $PORT_SOURCE \
        --backend-port $PORT_DEST \
        --frontend-ip-name lbFrontEnd \
        --backend-pool-name lbBackEnd \
        -ojsonc
    else
      tput setaf 3;  echo "Skipping Create Rule $1. Already exists."; tput sgr0
    fi

  local _fw=$(az network nsg rule show \
    --resource-group ${RESOURCE_GROUP} \
    --nsg-name $UNIQUE-vnet-subnet-nsg \
    --name $SECURITY_NAME \
    -ojsonc)

  local _highest=$(az network nsg rule list --resource-group ${RESOURCE_GROUP} --nsg-name $UNIQUE-vnet-subnet-nsg --query [].priority -otsv | sort -nr | head -n1)
  local _priority=$((_highest + 10))
  if [ "$_rule"  == "" ]
    then
      az network nsg rule create \
      --resource-group $RESOURCE_GROUP \
      --nsg-name $UNIQUE-vnet-subnet-nsg \
      --name $SECURITY_NAME \
      --direction inbound \
      --access allow \
      --protocol tcp \
      --source-address-prefix '*' \
      --source-port-range '*' \
      --destination-address-prefix '*' \
      --destination-port-range $PORT_DEST \
      --priority $_priority

    else
      tput setaf 3;  echo "Skipping Security Rule $1. Already exists."; tput sgr0
    fi


}
function RemoveLoadBalancerRule() {
  # Required Argument $1 = NAME
  # Required Argument $2 = PORT_SOURCE
  # Required Argument $3 = PORT_DEST

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RULE_NAME) not received'; tput sgr0
    exit 1;
  fi

  LB_NAME=$(GetLoadBalancer $RESOURCE_GROUP)
  PROBE_NAME=probe-$1
  RULE_NAME=rule-$1
  SECURITY_NAME=allow-$1

  local _rule=$(az network lb rule show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $RULE_NAME \
    --query name \
    -ojsonc)

  if [ "$_rule"  != "" ]
    then
      tput setaf 3;  echo "Delete Rule: $RULE_NAME"; tput sgr0
      az network lb rule delete \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $RULE_NAME \
        -ojsonc
    fi

  local _probe=$(az network lb probe show \
    --resource-group $RESOURCE_GROUP \
    --lb-name $LB_NAME \
    --name $PROBE_NAME \
    --query name \
    -ojsonc)

  if [ "$_probe"  != "" ]
    then
      tput setaf 3;  echo "Delete Probe: $PROBE_NAME"; tput sgr0
      az network lb probe delete \
        --resource-group $RESOURCE_GROUP \
        --lb-name $LB_NAME \
        --name $PROBE_NAME \
        -ojsonc
    fi

  local _fw=$(az network nsg rule show \
    --resource-group ${RESOURCE_GROUP} \
    --nsg-name $UNIQUE-vnet-subnet-nsg \
    --name $SECURITY_NAME \
    -ojsonc)

  if [ "$_fw"  != "" ]
    then
      tput setaf 3;  echo "Delete Inbound Security Rule: $SECURITY_NAME"; tput sgr0
      az network nsg rule delete \
        --resource-group ${RESOURCE_GROUP} \
        --nsg-name $UNIQUE-vnet-subnet-nsg \
        --name $SECURITY_NAME \
        -ojsonc
    fi
}

#////////////////////////////////
CATEGORY=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${CATEGORY}

case $ACTION in
create)
  if [ -z $NAME ]; then
    tput setaf 1; echo 'ERROR: NAME not found' ; tput sgr0
    usage;
  fi
  if [ -z $PORTS ]; then
    tput setaf 1; echo 'ERROR: PORTS not found' ; tput sgr0
    usage;
  fi
  PORT_DEST=${PORTS#*:}
  PORT_SOURCE=${PORTS%:*}

  echo "Creating LB Rule for" ${RESOURCE_GROUP}
  CreateLoadBalancerRule $NAME $PORT_SOURCE $PORT_DEST
  IP=$(az network public-ip list --resource-group ${RESOURCE_GROUP} --query "[?contains(name,'lb-ip')].ipAddress" -otsv)

  echo "http://${IP}:${PORT_SOURCE}"
  ;;
rm)
  if [ -z $NAME ]; then
    tput setaf 1; echo 'ERROR: NAME not found' ; tput sgr0
    usage;
  fi
  echo "Removing LB Rule for" ${RESOURCE_GROUP}
  RemoveLoadBalancerRule $NAME
  ;;
ls)
  echo "List LB Rules" ${RESOURCE_GROUP}
  LB_NAME=$(GetLoadBalancer $RESOURCE_GROUP)
  az network lb rule list \
      --resource-group $RESOURCE_GROUP \
      --lb-name $LB_NAME \
      --query '[].{name:name, "LB Port":frontendPort, "Swarm Port":backendPort, protocol:protocol}' \
      -otable
  ;;
*)
  usage
  ;;
esac
