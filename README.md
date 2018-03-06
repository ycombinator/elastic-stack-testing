# elastic-stack-testing

[WIP] Elastic Stack Testing Framework

This project is a work in progress to provide a common automation framework for elastic stack testing.
<br>The goal is to provide a powerful, easy to use and maintain framework to build test suites.  
<br>One main project for this framework is the development of a product integration test suite.
  - Automated Integration Testing (AIT)

This project is in early stage development and many things are still being ironed out.  

More details can be found:
- [Wiki](https://github.com/elastic/elastic-stack-testing/wiki)
- [Kanban Board](https://github.com/elastic/elastic-stack-testing/projects/1)

## Infrastructure

 - Software products under test: Elasticsearch, Kibana, Logstash, Beats, Cloud, APM
 - Ansible is used to install and configure the software products under test
 - Python, Pytest and Selenium/Webium will be used for the test framework
 - Automated virtual machine support for Vagrant boxes, AWS EC2 and GCP

## Environment Setup

 * Install Python 3

   In this repo see version file: .python-version

   https://www.python.org/downloads/

 * Install Vagrant

   In this repo see version: .vagrant-version

   https://www.vagrantup.com/downloads.html

 * Install Virtualbox

   In this repo see version file: .virtualbox-version

   https://www.virtualbox.org/wiki/Downloads

## Runnning Scripts

Run VM setup, product installation/configuration and tests
<br>buildenv.sh, fill in information below and then run ./buildenv.sh

  - <b>Build Variables</b>
    - export ES_BUILD_URL= build URL format: server/build_num-hash   
    - export ES_BUILD_PKG_EXT= package extension one of: tar, rpm, deb
    -  <b>Elasticsearch and Kibana change the default ports</b>
      - export AIT_ELASTICSEARCH_PORT=
      - export AIT_KIBANA_PORT=
    - <b>OS defaults to ubuntu 16.04, to change the default OS</b>
        - export ES_BUILD_VAGRANT_BOX=
  - <b>Ansible Variables</b>
    - AIT_ANSIBLE_PLAYBOOK - playbook for product installation   
      Example: AIT_ANSIBLE_PLAYBOOK=${AIT_ANSIBLE_PLAYBOOK_DIR}/install_no_xpack.yml
    - AIT_VM - machine setup which calls above playbook      
      Example: AIT_VM=${AIT_SCRIPTS}/shell/vagrant_vm.sh   
  - <b>Cloud Variables</b>
    - export ES_CLOUD_ID=
    - export AIT_ELASTICSEARCH_PASSWORD=
    - export AIT_ANSIBLE_PLAYBOOK=(ex: install_cloud)
  - <b>Test Variables</b>
    - <b>No X-Pack</b>
      -  export AIT_TESTS=run_pytest_integration_tests
    - <b>X-Pack</b>
      - export AIT_XPACK=true
      - export AIT_TESTS=run_pytest_integration_tests
    - <b>Cloud</b>
      - export AIT_XPACK=true
      - export AIT_ELASTICSEARCH_URL=es_url
      - export AIT_KIBANA_URL=kbn_url
      - export AIT_ELASTICSEARCH_PASSWORD=es_pw
      - export AIT_KIBANA_PASSWORD=kbn_pw
      - export AIT_TESTS=run_pytest_integration_tests
  - <b>Run playbook on an already running Vagrant VM</b>
    - <b>IMPORTANT!</b> Comment out AIT_VM variable
    - set AIT_HOST_INVENTORY_DIR, your running VM directory in your workspace ex:   
      6-0-0-rc2-3c6dc061_os_install_no_xpack
    - set AIT_ANSIBLE_PLAYBOOK to the playbook you want to run

Run Python Tests
<br>Pytest, run ./pyvenv.sh and cd to specific directory (ex: cd integration/tests)

  - <b>No X-Pack</b>
    -  pytest test_basic_integration
  - <b>X-Pack</b>
    - AIT_XPACK=true pytest test_basic_integration
  - <b>Cloud</b>
    - AIT_XPACK=true AIT_ELASTICSEARCH_URL=es_url AIT_KIBANA_URL=kbn_url
      AIT_ELASTICSEARCH_PASSWORD=es_pw AIT_KIBANA_PASSWORD=kbn_pw pytest test_basic_integration

## Currently Supported

  - Machine: vagrant/virtualbox
  - Machine OS: ubuntu-16.04-x86_64
  - Node: single
  - Software Versions: 5.6.x, 6.x, 7.x
  - Package: tar.gz
  - X-pack: with and without  

## Using Vagrant CLI

  If using Vagrant/Virtualbox through buildenv.sh script, a directory is created in ait_workspace that contains the
  Vagrantfile.  The directory is prefixed with the build id.  If the VM is running and you want to ssh, destroy or
  its not running and you want to start it, cd to this directory and run the vagrant command.

  Examples:
  - vagrant ssh
  - vagrant destroy -f

## Contributing

  Please use the issue tracker to report any bugs or enhancement requests.  Pull requests are welcome.

## Author

  Elastic Stack Testing Framework created by [Liza Dayoub](https://github.com/liza-mae)

## License

   Apache License 2.0

