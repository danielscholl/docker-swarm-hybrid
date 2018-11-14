# docker-swarm-hybrid

This is an Azure environment created using ARM templates to test Mixed OS Swarm features.

__Requirements:__

- Cloud Shell

## Installation
### Clone the repo

```
git clone https://github.com/danielscholl/docker-swarm-hybrid
cd docker-swarm-hybrid
```

### Create the private ssh keys

Access to the servers is via a ssh session and requires the user to create the SSH Keys in the home .ssh directory.

```bash
mkdir ~/.ssh && cd ~/.ssh
ssh-keygen -t rsa -b 2048 -C $(az account show --query user.name -otsv) -f id_rsa
```

### Provision IaaS using ARM Template scripts

The first step is to deploy the custom ARM Templates using the install.sh script.  The script has two optional arguments.

- worker count (The number of Manager Nodes desired to be created  ie: 2)
- manager count (The number of Nodes desired to be created  ie: 2)

```bash
./install.sh 5 3
```

### Configure the IaaS servers using Ansible Playbooks

Once the template is deployed properly a few Azure CLI commands are run to create the items not supported by ARM Templates.

1. A Storage Container is created for the REX-ray driver to use.
2. A Service Principle is created with a clientID and clientSecret for the REX-ray driver to use to access AZURE.

Three files are automatically created to support the ansible installation process with the proper values.

#### Ansible Configuration File 

This is the default ansible configuration file that is used by the provisioning process it identifies the location of the ssh keys and where the inventory file is located at.

```yaml
[defaults]
inventory = ./ansible/inventories/azure//hosts
private_key_file = ~/.ssh/id_rsa
host_key_checking = false
```

```bash
export ANSIBLE_CONFIG=./.ansible.cfg
```

### Validate Connectivity

Check and validate ansible connectivity once provisioning has been completed and begin to configure the node servers.

```bash
ansible all -m ping  #Check Connectivity
ansible-playbook ansible/playbooks/main.yml  # Provision the node Servers
```

### Upload Apps to File Share

```bash
./sync.sh
```

## Script Usage

- init.sh _unique_ _count_ (provision IaaS into azure)
- clean.sh _unique_ _count_ (delete IaaS from azure)
- connect.sh _unique_ _node_ (SSH Connect to the node instance)
- manage.sh _unique_ _command_ (deprovision/start/stop nodes in azure)
- lb.sh _unique_ (manage loadbalancer ports to the swarm)
  - lb.sh _unique_ ls  (list all lb rules)
  - lb.sh _unique_ create _name_ _portSrc:portDest_  (ie: create http 80:8080 --> Open port 80 map to 8080 on swarm and name it http)
  - lb.sh _unique_ rm _name_ (remove lb rule)
