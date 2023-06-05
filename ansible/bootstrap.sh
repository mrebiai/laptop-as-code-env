#!/usr/bin/env bash

set -e

echo "*** Updating Cache"
sudo apt update

echo "*** Installing Git"
sudo apt -y install git

echo "*** Checking SSH configuration"
mkdir -p ~/.ssh
keyName=$(find ~/.ssh/ -name *_key | head -1 | sed 's|.*ssh/||g')
if [[ "${keyName}" == "" ]]; then
  echo "No SSH Keys found"
  echo "Generate ssh key with ED25519 algorithm"
  read -e -p "my_login=" -i "${USER}" myLogin < /dev/tty
  ssh-keygen -t ed25519 -C "${myLogin}" -f ~/.ssh/${myLogin}_key < /dev/tty

  echo "Get public key content with: "
  echo -e "\tcat ~/.ssh/${myLogin}_key.pub"
  echo "Go to https://github.com/settings/keys and push your public key content with an expiration date (3 months for example)"
  echo "Finally run again your bootstrap command"
  exit 1
fi

echo "*** Re-generating public key"
read -sp 'SSH Passphrase: ' passphrase < /dev/tty
echo
chmod go-rwx ~/.ssh/${keyName}
ssh-keygen -P ${passphrase} -y -f ~/.ssh/${keyName} > ~/.ssh/${keyName}.pub
[[ -f ~/.ssh/config ]] && cp ~/.ssh/config ~/.ssh/config.bck
echo -e "Host github.com\n\tHostName github.com\n\tPort 22\n\tIdentityFile ~/.ssh/${keyName}\n\tUser git\n\tStrictHostKeyChecking no\n\tAddKeysToAgent yes\n" > ~/.ssh/config
printf '#!/bin/sh\necho $SSH_PASS' > ~/tmp-auto-add-key.sh
chmod u+x ~/tmp-auto-add-key.sh
eval $(ssh-agent)
SSH_PASS=${passphrase} DISPLAY=1 SSH_ASKPASS=~/tmp-auto-add-key.sh ssh-add ~/.ssh/${keyName} < /dev/null
rm ~/tmp-auto-add-key.sh
login=$(echo ${keyName} | sed 's/_key//')

echo "*** Installing Ansible"
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible python3-pip
sudo pip3 install psutil
# generate local env
echo "[defaults]
inventory = ~/.my-env
log_path = /var/log/ansible/ansible.log
deprecation_warnings = False
force_color = True" > ~/.ansible.cfg
sudo mkdir -p /var/log/ansible
sudo touch /var/log/ansible/ansible.log
sudo chown -R $(id -u):$(id -g) /var/log/ansible/
myLastName="xxx"
myFirstname=$(echo ${login} | cut -f1 -d'.')
myEmail="${login}@example.com"
myParameters="my_login=${login}"
read -e -p "my_first_name=" -i "${myFirstname^}" myFirstname < /dev/tty
read -e -p "my_last_name=" -i "${myLastName^}" myLastName < /dev/tty
myParameters="$myParameters my_first_name=${myFirstname}"
myParameters="$myParameters my_last_name=${myLastName}"
myParameters="$myParameters my_email=${myEmail}"
read -e -p "my_github_repos_dir(from ~)=" -i "github.com" myGitRepos < /dev/tty
myParameters="$myParameters my_github_repos_dir=${myGitRepos}"
read -e -p "Do you have (and want to use) an IntelliJ Ultimate license [y / n]: " -i "n" intellijLicense < /dev/tty
if [[ "${intellijLicense}" == "y" ]]; then
  myParameters="$myParameters intellij_idea_ultimate_license=True"
else
  myParameters="$myParameters intellij_idea_ultimate_license=False"
fi
read -e -p "Git url for your Ansible my-role: " -i "git@github.com:mrebiai/laptop-as-code-role-user.git" myRole < /dev/tty
read -e -p "Git version for your Ansible my-role: " -i "${login}" myVersion < /dev/tty
myParameters="$myParameters my_role_version=${myRole},${myVersion}"
echo -e "127.0.0.1\t${myParameters}" > ~/.my-env
echo
echo "You can update your answers here :"
echo -e "\t~/.my-env"
echo
echo "Testing Ansible"
ansible localhost -c local -m ping
echo
echo "Installing my-role"
rm -rf ~/.ansible/roles/*
ansible-galaxy install git+${myRole},${myVersion} --force-with-deps
echo
echo "You can now install all your configuration thanks to Ansible"
echo -e "\tansible-pull -U github.com:mrebiai/laptop-as-code-playbook.git -K"
echo
