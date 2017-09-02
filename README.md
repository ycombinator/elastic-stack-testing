# integration-testing

Elastic Stack: Automated Integration Testing (AIT)

## Infrastructure

 - Software products under test: Elasticsearch, Kibana, Logstash, Beats
 - Ansible is used to install and configure the software products under test
 - Python/Pytest and Selenium will be used for the test script framework
 - Automated virtual machine support for Vagrant boxes and AWS EC2 instances 

## Directory Structure

```
integration-testing/
  aitenv.sh        environment variable setup file
  ansible/         directory for Ansible 
  playbooks/       Ansible playbooks 
  tests/           test scripts
  vm/              automated VM files
```
 
## Environment Set Up

* Install Ansible 

  http://docs.ansible.com/ansible/latest/intro_installation.html

* Source AIT environment file

  source aitenv.sh 

* Fill out and source build information 
  
  source buildenv.sh 
 
* Fill out inventory 
  (Dynamic inventory setup will be added with VM creation soon)
  
  ${ANSIBLE_ROOTDIR}/host_vars/hosts
 
* Fill out variable information
 
  ${ANSIBLE_ROOTDIR}/group_vars/auto.yml
 
## Running Ansible Playbooks 

* cd playbooks 

  ansible-playbook <playbook_name>.yml --extra-vars="{uut: [hostname]}"
