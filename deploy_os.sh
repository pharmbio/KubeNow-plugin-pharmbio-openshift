#/!/bin/bash

set -e
set -x

# Run as serveradmin
sudo su serveradmin

DEPLOY_DIR=/deployments/tests
DEPLOY_NAME=ci-openshift-test
OS_VERSION=3.11

# Create deployment root dir
mkdir -p "$DEPLOY_DIR/$DEPLOY_NAME"
cd "$DEPLOY_DIR/$DEPLOY_NAME"

#
# install latest KubeNow (development/pharmbio) branch
#
curl -f "https://raw.githubusercontent.com/kubenow/KubeNow/development/pharmbio/bin/kn" -o "/tmp/kn"
sudo mv /tmp/kn /usr/local/bin/
sudo chmod +x /usr/local/bin/kn
sudo kn pull

# Creaye KubeNow init-directory
kn --plugin-repo https://github.com/pharmbio/KubeNow-plugin-pharmbio-openshift.git init kvm "kubenow-$DEPLOY_NAME"
cd "$DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME"

# Edit kubenow config (vim config.tfvars)
sed -i -e "s/your-cluster-prefix/$DEPLOY_NAME/g" config.tfvars
sed -i -e "s/master_ip_if1.*/master_ip_if1 = [\"10.10.0.16\"]/g" config.tfvars
sed -i -e "s/master_ip_if2.*/master_ip_if2 = [\"130.238.44.16\"]/g" config.tfvars
sed -i -e "s/node_ip_if1.*/node_ip_if1 = [\"10.10.0.26\"]/g" config.tfvars
sed -i -e "s/node_ip_if2.*/node_ip_if2 = [\"130.238.44.26\"]/g" config.tfvars
sed -i -e "s/master_vcpu.*/master_vcpu = \"2\"/g" config.tfvars
sed -i -e "s/master_memory.*/master_memory = \"8096\"/g" config.tfvars
sed -i -e "s/master_disk_size.*/master_disk_size = \"50\"/g" config.tfvars
sed -i -e "s/node_vcpu.*/node_vcpu = \"2\"/g" config.tfvars
sed -i -e "s/node_memory.*/node_memory = \"8096\"/g" config.tfvars
sed -i -e "s/node_disk_size.*/node_disk_size = \"50\"/g" config.tfvars

# Deploy infrastructure with KubeNow
kn apply

# Exit KubeNow dir
cd "$DEPLOY_DIR/$DEPLOY_NAME"

# Clone Services repo
git clone git@github.com:pharmbio/services-ansible.git
git -C services-ansible checkout anders/dev2 # could be master branch in future

# Clone Openshift repo
git clone https://github.com/openshift/openshift-ansible.git
git -C openshift-ansible checkout release-${OS_VERSION}


# -------------- EDIT inventory file ------------------
# vim "$DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME/inventory" 


# pull latest image
docker pull docker.io/openshift/origin-ansible:v${OS_VERSION}

# Extra prerequisites (network host is needed for testing ssh is available)
# Mount playbook-dir, inventory file and ssh-key to docker container
docker run -t \
   --network host \
   -u `id -u` \
   -v $DEPLOY_DIR/$DEPLOY_NAME/services-ansible:/services-ansible:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME/ssh_key:/opt/app-root/src/.ssh/id_rsa:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME/inventory:/tmp/inventory:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/services-ansible/test_htpasswd:/tmp/test_htpasswd \
   -v /home/anders/.ansible_vault.key:/tmp/vault-pwd-file \
   -e ANSIBLE_VAULT_PASSWORD_FILE=/tmp/vault-pwd-file \
   -e INVENTORY_FILE=/tmp/inventory \
   -e PLAYBOOK_FILE=/services-ansible/extra-presequisites.yml \
   -e ANSIBLE_STDOUT_CALLBACK=debug \
   -e OPTS="-v" \
   docker.io/openshift/origin-ansible:v${OS_VERSION}
   
# Origin-ansible Prerequisites 
docker run -t \
   --network host \
   -u `id -u` \
   -v $DEPLOY_DIR/$DEPLOY_NAME/openshift-ansible:/openshift-ansible:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME/ssh_key:/opt/app-root/src/.ssh/id_rsa:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME/inventory:/tmp/inventory:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/services-ansible/test_htpasswd:/tmp/test_htpasswd \
   -v /home/anders/.ansible_vault.key:/tmp/vault-pwd-file \
   -e ANSIBLE_VAULT_PASSWORD_FILE=/tmp/vault-pwd-file \
   -e INVENTORY_FILE=/tmp/inventory \
   -e PLAYBOOK_FILE=/openshift-ansible/playbooks/prerequisites.yml \
   -e ANSIBLE_STDOUT_CALLBACK=debug \
   -e OPTS="-v" \
   docker.io/openshift/origin-ansible:v${OS_VERSION}
   
docker run -t \
   --network host \
   -u `id -u` \
   -v $DEPLOY_DIR/$DEPLOY_NAME/openshift-ansible:/openshift-ansible:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME/ssh_key:/opt/app-root/src/.ssh/id_rsa:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/kubenow-$DEPLOY_NAME/inventory:/tmp/inventory:Z \
   -v $DEPLOY_DIR/$DEPLOY_NAME/services-ansible/test_htpasswd:/tmp/test_htpasswd \
   -v /home/anders/.ansible_vault.key:/tmp/vault-pwd-file \
   -e ANSIBLE_VAULT_PASSWORD_FILE=/tmp/vault-pwd-file \
   -e INVENTORY_FILE=/tmp/inventory \
   -e PLAYBOOK_FILE=/openshift-ansible/playbooks/deploy_cluster.yml \
   -e ANSIBLE_STDOUT_CALLBACK=debug \
   -e OPTS="-v" \
   docker.io/openshift/origin-ansible:v${OS_VERSION}
