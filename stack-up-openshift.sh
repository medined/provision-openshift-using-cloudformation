#!/bin/bash

export REGION_NAME="us-east-1"

if [ -z $REGION_NAME ]; then
  echo "Set REGION_NAME"
  exit 1
fi

if [ -z ${AWS_PROFILE} ]; then
  echo "AWS_PROFILE is unset. Using default AWS Credentials. Is this correct?";
else
  echo "Your AWS profile does not affect generation. But it does affect stack";
  echo "creation (i.e. when stacks_up and stacks_destroy are run)."
  echo "AWS_PROFILE is set to '$AWS_PROFILE'. Is this correct?";
fi

select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "Excellent!"; break;;
        No ) echo "Oh no! Please fix your AWS_PROFILE variable."; exit;;
    esac
done

source source-me.sh

##########
# TODO: test the existence of each env var.
##########

echo "Openshift started."
aws cloudformation deploy \
  --stack-name $Z34_STACK_NAME \
  --region $Z34_REGION_NAME \
  --capabilities CAPABILITY_NAMED_IAM \
  --template-file $Z34_TEMPLATE_FILE \
  --parameter-overrides \
      pAMI=$Z34_AMI \
      pAvailabilityZone=$Z34_AVAILABILITY_ZONE \
      pInstanceType=$Z34_INSTANCE_TYPE \
      pKeyName=$Z34_KEYNAME \
      pSubnet=$Z34_PUBLIC_SUBNET \
      pVPC=$Z34_VPC \
      pVpcCidrBlock=$Z34_VPC_CIDR_BLOCK

#############################
echo "Getting IP addresses."
#############################

IP_MASTER_EXPORT="openshift:MasterPublicIp"
IP_WORKER1_EXPORT="openshift:Worker1PublicIp"
IP_WORKER2_EXPORT="openshift:Worker2PublicIp"

IP_MASTER=$(aws cloudformation list-exports \
  --query "Exports[?Name==\`${IP_MASTER_EXPORT}\`].Value" \
  --output text)

if [ -z ${IP_MASTER} ]; then
  echo "ERROR: Missing CloudFormat export: ${IP_MASTER_EXPORT}";
  exit
fi

IP_WORKER1=$(aws cloudformation list-exports \
  --query "Exports[?Name==\`${IP_WORKER1_EXPORT}\`].Value" \
  --output text)

if [ -z ${IP_WORKER1} ]; then
  echo "ERROR: Missing CloudFormat export: ${IP_WORKER1_EXPORT}";
  exit
fi

IP_WORKER2=$(aws cloudformation list-exports \
  --query "Exports[?Name==\`${IP_WORKER2_EXPORT}\`].Value" \
  --output text)

if [ -z ${IP_WORKER2} ]; then
  echo "ERROR: Missing CloudFormat export: ${IP_WORKER2_EXPORT}";
  exit
fi

echo "Master   IP: $IP_MASTER"
echo "Worker 1 IP: $IP_WORKER1"
echo "Worker 2 IP: $IP_WORKER2"

#############################
echo "Collecting server ECDSA key fingerprints."
#############################

if [ "`ssh-keygen -F $IP_MASTER | wc -l`" -eq "0" ]; then
  ssh-keyscan -H $IP_MASTER >> ~/.ssh/known_hosts
fi

if [ "`ssh-keygen -F $IP_WORKER1 | wc -l`" -eq "0" ]; then
  ssh-keyscan -H $IP_WORKER1 >> ~/.ssh/known_hosts
fi

if [ "`ssh-keygen -F $IP_WORKER2 | wc -l`" -eq "0" ]; then
  ssh-keyscan -H $IP_WORKER2 >> ~/.ssh/known_hosts
fi

#############################
echo "Waiting for Master to respond to SSH."
#############################

STATUS=$(ssh -o ConnectTimeout=2 -o BatchMode=yes -i $Z34_PEM_FILE centos@$IP_MASTER pwd)
while [ "${STATUS}x" != "/home/centosx" ]; do
  echo -n "."
  sleep 10
  STATUS=$(ssh -o ConnectTimeout=2 -o BatchMode=yes -i $Z34_PEM_FILE centos@$IP_MASTER pwd)
done
echo ""

#############################
echo "Waiting for Worker1 to respond to SSH."
#############################

STATUS=$(ssh -o ConnectTimeout=2 -o BatchMode=yes -i $Z34_PEM_FILE centos@$IP_WORKER1 pwd)
while [ "${STATUS}x" != "/home/centosx" ]; do
  echo -n "."
  sleep 10
  STATUS=$(ssh -o ConnectTimeout=2 -o BatchMode=yes -i $Z34_PEM_FILE centos@$IP_WORKER1 pwd)
done
echo ""

#############################
echo "Waiting for Worker2 to respond to SSH."
#############################

STATUS=$(ssh -o ConnectTimeout=2 -o BatchMode=yes -i $Z34_PEM_FILE centos@$IP_WORKER2 pwd)
while [ "${STATUS}x" != "/home/centosx" ]; do
  echo -n "."
  sleep 10
  STATUS=$(ssh -o ConnectTimeout=2 -o BatchMode=yes -i $Z34_PEM_FILE centos@$IP_WORKER2 pwd)
done
echo ""

#############################
echo "Writing inventory file."
#############################

cat <<EOF >inventory
[OSEv3:children]
masters
etcd
nodes

[OSEv3:vars]
ansible_ssh_user=centos
ansible_sudo=true
ansible_become=true
deployment_type=origin
os_sdn_network_plugin_name='redhat/openshift-ovs-multitenant'
openshift_install_examples=true
openshift_docker_options='--selinux-enabled --insecure-registry 172.30.0.0/16'
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider', 'filename': '/etc/openshift/openshift-passwd'}]
openshift_disable_check=disk_availability,docker_storage,memory_availability
openshift_release=3.9

[masters]
$IP_MASTER

[etcd]
$IP_MASTER

[nodes]
$IP_MASTER openshift_node_labels="{'region':'infra','zone':'east'}" openshift_schedulable=true
$IP_WORKER1 openshift_node_labels="{'region': 'primary', 'zone': 'east'}"
$IP_WORKER2 openshift_node_labels="{'region': 'primary', 'zone': 'east'}"
EOF

#############################
echo "Running Ansible playbook."
#############################

ansible-playbook \
  --inventory $Z34_INVENTORY_FILE \
  --key-file $Z34_PEM_FILE \
  prepare.yml

#############################
echo "Example SSH commands."
#############################

echo "ssh -i $Z34Z34_PEM_FILE centos@$IP_MASTER"
echo "ssh -i $Z34Z34_PEM_FILE centos@$IP_WORKER1"
echo "ssh -i $Z34Z34_PEM_FILE centos@$IP_WORKER2"

#############################
echo "Cloning Openshift Ansible from GitHub."
######
# Note that v3.11 of ansible requires a change to
# the inventory file. I don't know how to make the
# correct change. v3.9 works fine.
#############################

if [ ! -d "openshift-ansible" ]; then
  git clone https://github.com/openshift/openshift-ansible.git
  cd openshift-ansible
  git checkout origin/release-3.9
else
  cd openshift-ansible
fi

ansible-playbook \
  --inventory ../$Z34_INVENTORY_FILE \
  --key-file $Z34_PEM_FILE \
  playbooks/prerequisites.yml

ansible-playbook \
  --inventory ../$Z34_INVENTORY_FILE \
  --key-file $Z34_PEM_FILE \
  playbooks/deploy_cluster.yml

cd ..

#############################
echo "Openshift: setting $Z34_HTPASSWD_USERNAME password."
#############################

ssh \
  -i $Z34_PEM_FILE \
  centos@$IP_MASTER \
  sudo htpasswd -b /etc/openshift/openshift-passwd $Z34_HTPASSWD_USERNAME $Z34_HTPASSWD_PASSWORD

#############################
echo "Saving OpenShift username and password to Parameter Store."
#############################

aws ssm put-parameter \
  --name ${Z34_STACK_NAME}-username \
  --value $Z34_HTPASSWD_USERNAME \
  --type String \
  --overwrite > /dev/null

aws ssm put-parameter \
  --name ${Z34_STACK_NAME}-password \
  --value $Z34_HTPASSWD_PASSWORD \
  --type String \
  --overwrite > /dev/null

#############################
echo "Openshift: checking node status."
#############################

ssh -i $Z34_PEM_FILE centos@$IP_MASTER oc get nodes

#############################
echo "Openshift: Web Console URL: https://$IP_MASTER:8443"
echo ""
echo "   The OC Binary"
echo "   -------------"
echo "   If you don't have the oc binary installed, download it from the"
echo "   openshift console after you log into it."
echo ""
echo "For security reasons, the web console username and password will not"
echo "be displayed. You can retreive them from the AWS Parameter Store with"
echo "the following commands."
echo ""
echo "   Web Console User"
echo "   -------------"
echo "   aws ssm get-parameter --name $Z34_HTPASSWD_USERNAME --query 'Parameter.Value' --output text"
echo ""
echo "   Web Console Password"
echo "   -------------"
echo "   aws ssm get-parameter --name $Z34_HTPASSWD_PASSWORD --query 'Parameter.Value' --output text"
echo ""
echo "   OC Login"
echo "   -------------"
echo "   After you log into the web console, get your login command from"
echo "   the menu on the top right."
#############################
