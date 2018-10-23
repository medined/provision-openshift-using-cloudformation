# Provision Openshift Using CloudFormation

## Based On

* https://sysdig.com/blog/deploy-openshift-aws/

## Prerequisites

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
