# elastic-stack-testing

[WIP] Elastic Stack: Automated Integration Testing (AIT)

## Infrastructure

This project is a work in progress to provide a common automation framework for elastic stack integration testing.
The goal is to provide a powerful, easy to use and maintain framework to build test suites.

 - Software products under test: Elasticsearch, Kibana, Logstash, Beats
 - Ansible is used to install and configure the software products under test
 - Python, Pytest and Selenium will be used for the test framework
 - Automated virtual machine support for Vagrant boxes and AWS EC2 instances

This project is in early stage development and many things are still being ironed out.

## Directory Structure

```
elastic-stack-testing/
  ansible/         directory for Ansible
  buildenv.sh      shell script for running scripts locally
  playbooks/       Ansible playbooks
  tests/           test scripts
  vm/              automated VM files
```

## Environment Setup

 * Install Virtualbox and Vagrant

  - https://www.virtualbox.org/wiki/Downloads
  - https://www.vagrantup.com/downloads.html

* Install Python 3

  In this repo see file: .python-version for version to install

  https://www.python.org/downloads/

## Runnning Scripts

* buildenv.sh, fill in information below and then run ./buildenv.sh   

  - Build Variables
    - export ES_BUILD_URL= build URL format: server/build_num-hash   
    - export ES_BUILD_PKG_EXT= package extension one of: tar, rpm, deb


  - Elasticsearch and Kibana host ports default to 9200 and 5601, to change the default ports:
    - export AIT_ELASTICSEARCH_PORT=
    - export AIT_KIBANA_PORT=


  - OS defaults to ubuntu 16.04, to change the default OS:
    - export ES_BUILD_VAGRANT_BOX=


  - Ansible Standalone Variables (Product installation only - no Pytest) [** Phase 1 Pilot Testing ** ]
    - AIT_ANSIBLE_PLAYBOOK - playbook for product installation   
      Example: AIT_ANSIBLE_PLAYBOOK=${AIT_ANSIBLE_PLAYBOOK_DIR}/install_no_xpack.yml

    - AIT_ANSIBLE_SCRIPT - machine setup which calls above playbook      
      Example: AIT_ANSIBLE_SCRIPT=${AIT_SCRIPTS}/shell/setup_vagrant_vm.sh   

  - To run playbook on already running VM:
    - <b>IMPORTANT!</b> Comment out AIT_ANSIBLE_SCRIPT variable
    - set AIT_HOST_INVENTORY_ROOTDIR, your running VM directory in your workspace ex: 6-0-0-rc2-3c6dc061_os_install_no_xpack
    - set AIT_ANSIBLE_PLAYBOOK to the playbook you want to run

* Pytest Variables [** Phases 2/3 Pilot Testing ** ] - coming soon

## Running on Windows

  If running Ansible playbooks they need to be run from MacOS or Linux, although Windows Subsystem for Linux has support,
  it is not recommended to use this option.

## Pilot Testing

  - Phase 1: Ansible standalone product installation/configuration
      - Machine: vagrant/virtualbox
      - Machine OS: ubuntu-16.04-x86_64
      - Node: single
      - Software Versions: 5.6.x and 6.0.0
      - Package: tar.gz
      - X-pack: with and without  


  - Phase 2: Pytest tests - coming soon

  - Phase 3: Integrated Pytest ansible/tests - coming soon

## Using Vagrant CLI

  If using Vagrant/Virtualbox through buildenv.sh script, a directory is created in ait_workspace that contains the
  Vagrantfile.  The directory is prefixed with the build id.  If the VM is running and you want to ssh, destroy or
  its not running and you want to start it, cd to this directory and run the vagrant command.

  Examples:
  - vagrant ssh
  - vagrant destroy -f

## Contact

  For questions or help please contact: liza.dayoub@elastic.co
