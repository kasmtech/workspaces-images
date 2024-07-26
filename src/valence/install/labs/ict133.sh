#!/bin/bash

# Step 1: Clone repositories
cd /
git clone https://$PAT@github.com/suss-vli/ilabguide.git
git clone https://$PAT@github.com/suss-vli/suss.git
git clone https://$PAT@github.com/suss-vli/learntools.git

unset PAT

# Step 2: Copy files and create directories
mkdir -p $HOME/Desktop/ilabguide
cp ilabguide/ict133/ict133_questions/* $HOME/Desktop/ilabguide/
cp ilabguide/ict133/config_ict133.yml $HOME/Desktop/ilabguide/.config.yml

mkdir -p /opt/suss/customscripts/ict133/.encrypted_ict133_solution
cp -r ilabguide/ict133/.encrypted_ict133_solution/* /opt/suss/customscripts/ict133/.encrypted_ict133_solution/

mkdir -p $HOME/.local/share/applications && \
echo '[Default Applications]' > $HOME/.local/share/applications/mimeapps.list && \
echo 'application/x-ipynb+json=code.desktop' >> $HOME/.local/share/applications/mimeapps.list

# Step 3: Install packages
cd /
pip3 install ./suss
pip3 install ./learntools
pip3 install -r ./ilabguide/ict133/requirements.txt

wget https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.1.0/gcm-linux_amd64.2.1.0.deb && \
dpkg -i gcm-linux_amd64.2.1.0.deb && \
rm -rfv gcm-linux_amd64.2.1.0.deb