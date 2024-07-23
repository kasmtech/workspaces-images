Step 1:
cd /
git clone https://$PAT@github.com/suss-vli/ilabguide.git
git clone https://$PAT@github.com/suss-vli/suss.git
git clone https://$PAT@github.com/suss-vli/learntools.git

Step 2:
Files and folders to copy from ilabguide repository to the respective folders. You need to create these directories:

ilabguide/ict133/ict133_questions/lab1-6.ipynb > $HOME/Desktop/labguide
ilabguide/ict133/config_ict133.yml > /opt/suss/customscripts/.config.yml
ilabguide/ict133/.encrypted_ict133_solution/* > /opt/suss/customscripts/ict133/.encrypted_ict133_solution

Step 3:
cd /
pip3 install ./suss
pip3 install ./learntools
pip3 install -r ./ilabguide/ict133/requirements.txt