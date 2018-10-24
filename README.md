# Provision Openshift Using CloudFormation

This project creates an OpenShift cluster with one master and two nodes. It
takes about 15 minutes to fully configure the three nodes. After the script
runs, you can log into the web console. Simply follow information displayed
at the end of the execution.

## Based On

* https://sysdig.com/blog/deploy-openshift-aws/

## Prerequisites

### AWS CLI

I am using v1.14.44.

### AWS Credentials

I use the AWS_PROFILE variable and suggest that you do as well. In fact,
the scripts will confirm its value before execution.

### Ansible

On the system running the installation script, please make sure that
you are running Ansible v2.6.5.

```
sudo pip install 'ansible==2.6.5'
```

### Environment Variables

Copy the source-me.sh.example file to source.me.sh. Edit the file to change
the values as needed.

## Running the script

```
./stack-up-openshift.sh
```
