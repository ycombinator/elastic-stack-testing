# elastic-stack-testing

Automated Integration Testing (AIT)

## Infrastructure

 - Software products under test: Elasticsearch, Kibana, Logstash, Beats
 - Ansible is used to install and configure the software products under test
 - Python, Pytest and Selenium will be used for the test framework
 - Automated virtual machine support for Vagrant boxes and AWS EC2 instances

## Directory Structure

```
elastic-stack-testing/
  ansible/         directory for Ansible
  buildenv.sh      shell script for running scripts locally
  playbooks/       Ansible playbooks
  tests/           test scripts
  vm/              automated VM files
```

## Environment Set Up

 * Install Virtualbox and Vagrant

  - https://www.virtualbox.org/wiki/Downloads
  - https://www.vagrantup.com/downloads.html

* Install Python 3

  https://www.python.org/downloads/

* Install Ansible

  http://docs.ansible.com/ansible/latest/intro_installation.html

## Running Scripts

* buildenv.sh - fill in information below and then run ./buildenv.sh   

  - Build Variables
    - ES_BUILD_URL - build URL format: server/build_num-hash   
    - ES_BUILD_PKG_EXT - package extension one of: tar, rpm, deb
  - Pytest Variables
    - Coming soon
  - Ansible Standalone Variables (Product installation only - no Pytest)
    - AIT_ANSIBLE_PLAYBOOK - playbook for product installation   
      Example: AIT_ANSIBLE_PLAYBOOK=${AIT_ANSIBLE_PLAYBOOK_DIR}/install_no_xpack.yml
    - AIT_ANSIBLE_SCRIPT - machine setup which calls above playbook      
      Example: AIT_ANSIBLE_SCRIPT=${AIT_SCRIPTS}/shell/setup_vagrant_vm.sh   
