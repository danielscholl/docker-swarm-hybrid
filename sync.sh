#!/usr/bin/env bash
#
#  Purpose: Sync folders to containers in a storage account
#  Usage:
#    sync.sh <resourcegroup> <folder>


###############################
## ARGUMENT INPUT            ##
###############################
usage() { echo "Usage: sync.sh <unique> <folder>" 1>&2; exit 1; }

if [ -f ~/.azure/.env ]; then source ~/.azure/.env; fi
if [ -f ./.env ]; then source ./.env; fi
if [ -f ./functions.sh ]; then source ./functions.sh; fi


if [ ! -z $1 ]; then UNIQUE=$1; fi
if [ -z $UNIQUE ]; then
  tput setaf 1; echo 'ERROR: UNIQUE not found' ; tput sgr0
  usage;
fi

if [ ! -z $2 ]; then CONTAINER=$2; fi
if [ -z $CONTAINER ]; then
  CONTAINER="apps"
fi

###############################
## FUNCTIONS                 ##
###############################
function GetStorageAccount() {
  # Required Argument $1 = RESOURCE_GROUP

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received' ; tput sgr0
    exit 1;
  fi

  local _storage=$(az storage account list --resource-group $1 --query [].name -otsv)
  echo ${_storage}
}
function GetStorageAccountKey() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = STORAGE_ACCOUNT

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (STORAGE_ACCOUNT) not received'; tput sgr0
    exit 1;
  fi

  local _result=$(az storage account keys list \
    --resource-group $1 \
    --account-name $2 \
    --query '[0].value' \
    --output tsv)
  echo ${_result}
}
function GetStorageConnection() {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = STORAGE_ACCOUNT

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (RESOURCE_GROUP) not received'; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (STORAGE_ACCOUNT) not received'; tput sgr0
    exit 1;
  fi

  local _result=$(az storage account show-connection-string \
    --resource-group $1 \
    --name $2\
    --query connectionString \
    --output tsv)

  echo $_result
}
function CreateFileShare() {
  # Required Argument $1 = CONTAINER_NAME
  # Required Argument $2 CONNECTION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (CONTAINER_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (STORAGE_CONNECTION) not received' ; tput sgr0
    exit 1;
  fi

  az storage share create --name $1 \
    --quota 2048 \
    --connection-string $2 \
    -ojsonc
}
function CreateFileShareDir() {
  # Required Argument $1 = DIRECTORY_NAME
  # Required Argument $2 = SHARE_NAME
  # Required Argument $3 CONNECTION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (DIRECTORY_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (SHARE_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $3 ]; then
    tput setaf 1; echo 'ERROR: Argument $3 (STORAGE_CONNECTION) not received' ; tput sgr0
    exit 1;
  fi

  az storage directory create --name $1 \
    --share-name $2 \
    --connection-string $3 \
    -ojsonc
}
function UploadFile() {
  # Required Argument $1 = SOURCE
  # Required Argument $2 = SHARE_NAME
  # Required Argument $3 CONNECTION

  if [ -z $1 ]; then
    tput setaf 1; echo 'ERROR: Argument $1 (SOURCE) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $2 ]; then
    tput setaf 1; echo 'ERROR: Argument $2 (SHARE_NAME) not received' ; tput sgr0
    exit 1;
  fi
  if [ -z $3 ]; then
    tput setaf 1; echo 'ERROR: Argument $3 (STORAGE_CONNECTION) not received' ; tput sgr0
    exit 1;
  fi

  if [[ $1 =~ .*\..* ]]
  then
    az storage file upload --source $1 --path $1 \
    --share-name $2 \
    --connection-string $3 \
    -ojsonc
  else
    az storage file upload --source $1 --path "$1." \
    --share-name $2 \
    --connection-string $3 \
    -ojsonc
  fi
}


###############################
## Azure Intialize           ##
###############################
BASE=${PWD##*/}
RESOURCE_GROUP=${UNIQUE}-${BASE}


##############################
## Folder Sync              ##
##############################
BASE_DIR="$PWD"
cd $CONTAINER

tput setaf 2; echo "Creating the $CONTAINER file share..." ; tput sgr0
STORAGE_ACCOUNT=$(GetStorageAccount $RESOURCE_GROUP)
STORAGE_KEY=$(GetStorageAccountKey $RESOURCE_GROUP $STORAGE_ACCOUNT)
CONNECTION=$(GetStorageConnection $RESOURCE_GROUP $STORAGE_ACCOUNT)
CreateFileShare $CONTAINER $CONNECTION

# Create Directory Structure
for d in $(find * -type d)
do
  tput setaf 2; echo "Creating the directory $d..." ; tput sgr0
  CreateFileShareDir $d $CONTAINER $CONNECTION
done

# Upload Files
for f in $(find * -type f)
do
  tput setaf 2; echo "Uploading the file $f..." ; tput sgr0
  UploadFile $f $CONTAINER $CONNECTION
done

cd ..
ansible manager -a "mount -t cifs //$STORAGE_ACCOUNT.file.core.windows.net/$CONTAINER $CONTAINER -o vers=3.0,username=$STORAGE_ACCOUNT,password=$STORAGE_KEY,dir_mode=0777,file_mode=0777,sec=ntlmssp" --become
