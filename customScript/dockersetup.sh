#!/bin/bash
# cat dockerstup.sh | gzip -9 | base64 -w0

#	Update package index
apt-get update

#	Install tools
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

#	Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

#	Setup stable repo
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

#	Update package index (again)
apt-get update

#	Install latest version of Docker CE
apt-get install docker-ce -y
