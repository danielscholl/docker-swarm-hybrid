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
