## Stack Monitoring Parity Tests

### Motivation

Traditionally, Elasticsearch, Kibana, and Logstash have internally collected their own monitoring data and shipped it 
to Elasticsearch. We refer to this traditional method as **internal collection** or **native collection**.

For several reasons that are outside the scope of this document, we want to moving data collection and shipping to an 
external agent, something that runs separately but along side each Elasticsearch node, Kibana instance, and Logstash
node. This agent will be Metricbeat. It will periodically call HTTP APIs exposed by Elasticsearch, Kibana, and 
Logstash to collect monitoring data and ship it to Elasticsearch. We refer to this new method as **Metricbeat 
collection**.

Our goal is for the Stack Monitoring UI in Kibana to work regardless of which collection method is used. This goal
can be accomplished by ensuring that the documents indexed by the internal collection method are identical in 
structure to those indexed by Metricbeat collection. The tests in this folder assert that this parity is maintained.

### How do the tests work?

At the topmost level, the parity tests are separated by the product being monitored — Elasticsearch, Kibana, and 
Logstash. Each product's parity tests are run via an Ansible playbook.

Each product's tests follow this general high-level approach:

1. Install Elasticsearch
1. Install product
1. Enable internal collection
1. Run the product for 30 seconds to collect monitoring data internally and index it into the Monitoring index for 
   that product
1. Stop the product
1. Download sample documents from the product's Monitoring index
1. Disable internal collection
1. Install Metricbeat
1. Enable Metricbeat collection for the product
1. Start the product
1. Start Metricbeat
1. Run the product and Metricbeat for 30 seconds to collect monitoring externally and index it into the Monitoring 
   index for that product
1. Stop the product
1. Stop Metricbeat
1. Download sample documents from the product's Monitoring index
1. Compare the internally-collected documents with Metricbeat-collected documents and verify parity of structure

### Diagnosing test failures

These tests run in Jenkins CI, about once a day. There is a CI job per active branch / version of the Elastic Stack, 
e.g. `master`, `7.x`, etc. Search for `estf-monitoring` under https://internal-ci.elastic.co/view/Stack%20Tests/.

When a CI job for this test fails, look at the console output for the failed job in Jenkins. Note the branch and 
snapshot URL that were used. Snapshot URLs look like `https://snapshots.elastic.co/$VERSION-$SHA`.

Tests can fail for multiple reasons. The most common ones are that the very last step in the test process failed — 
that documents of the same type did not have structural parity with each other. This type of failure usually 
indicates that code needs to be updated in either the product's internal collection mechanisms or in the Metricbeat 
module for the product.

At other times, tests fail because the product could not be configured or run correctly. This type of failure usually 
indicates that code for these tests itself needs to be changed.

The first step in determining the exact failure is to try and reproduce the test run locally. Once you've done that, 
look at the output from the test run, particularly the output of the very last Ansible play that ran and failed. It 
usually contains enough of a hint as to what caused the failure. Then, depending on what you find there, you may need 
to dig deeper.

See the sections below on how to run the tests locally and some useful diagnosis tips.

#### Running the tests

1. Clone this repository, say into a folder named `elastic-stack-testing`.

   ```
   git clone git@github.com:elastic/elastic-stack-testing.git
   cd elastic-stack-testing
   ```

2. Switch to the branch whose tests are failing.

   ```
   git checkout $BRANCH # e.g. `master`, `7.x`, etc.
   ```

3. Edit `playbooks/monitoring/buildenv.sh` and set `ES_BUILD_URL=` to the snapshot URL from the failing CI job.

   ```
   export ES_BUILD_URL=https://snapshots.elastic.co/$VERSION-$SHA
   ```

4. Run the tests.

   ```
   AIT_STACK_PRODUCT=$product ./playbooks/monitoring/buildenv.sh
   ```

   Where, `$product` must be either `elasticsearch` or `kibana`, depending on which product's tests you want to run.

   The tests will take a few minutes to run, spinning up a VM in VirtualBox, installing the various products in that 
   VM and performing the test steps outlined earlier.

   As the tests are running they will output the results in your Terminal console. This will be quite verbose and you 
   can ignore most of it until the tests finish. Then inspect at the output of the last play that ran and failed.

#### Diagnosis tips

##### Parity failures

As mentioned in the test steps earlier, the test downloads sample documents from the product's Monitoring index twice 
— once after internal collection and once after Metricbeat collection. Then the two sets of documents are compared
for structural parity.

The downloaded documents are stored under the `ait_workspace/monitoring/$PRODUCT` folder, where `$PRODUCT` is the 
product being monitored, e.g. `elasticsearch`, `kibana`, or `logstash`. Under this folder are two sub-folders, 
`internal` and `metricbeat`, corresponding to the two collection approaches. Under each of these folders are the 
various types of documents collected by each collection approach. There is a JSON file for each type of document, and 
"type" here corresponds to the value of the `type` field in the indexed documents. The contents of each JSON file are 
a sample document of that type.

The first thing to check is that the number and names of documents under the `internal` and `metridbeat` folders are 
the same. If there are fewer documents under one folder than the other, then that likely means that some types of 
documents did not get collected and indexed by one of the approaches and further investigation is needed.

If the number and names match up, then go back and look at the error message from the failed play in the test run 
output. It will indicate which type of document failed the parity test. Find the files with this type name in the 
`internal` and `metricbeat` folders. Compare their contents for structural differences using a tool such as 
http://www.jsondiff.com/. 

Note that certain structural differences are actually expected, therefore okay. For instance, Metricbeat-collected 
documents will have the `ecs`, `@timestamp`, and other such fields. Such differences can be safely ignored. To see 
what differences are expected, look at the `docs_compare.py` script under the `playbooks/monitoring/$PRODUCT` folder 
and look for the variable named `allowed_insertions`. 

After ignoring the expected structural differences, you'll be left with the unexpected structural differences. 
Depending on what you find here, you'll need to file issues in the `elastic/$PRODUCT`'s repository (requiring changes 
in the `$PRODUCT`'s internal collection code) or the `elastic/beats` repository (requiring changes in the
`$PRODUCT`'s Metricbeat module code).

##### Setup failures

Sometimes the tests fail to configure or start a product such as Metricbeat, Elasticsearch, etc. To determine why 
this happened, SSH into the Vagrant VM and look at the configuration files or logs for the product in question.

To SSH into the Vagrant VM, find the folder under `ait_workspace` that is named like `$VERSION-$SHA_os`. The 
`$VERSION-$SHA` part of the folder name will correspond to the `$VERSION-$SHA` you set for the `ES_BUILD_URL` 
variable in `playbooks/monitoring/buildenv.sh`. Change into this folder, then run `vagrant ssh`.

Once SSH'd into the VM, change to root by running `sudo su -`. Then `cd /tmp` and find the folder under there for the 
product that failed setup. Change into that product's folder and inspect its configuration or log files. You can also 
try to run the product's executable at that time to see what happens.

Note what you find and file a bug in the `elastic/elastic-stack-testing` repository, requiring a fix to the parity 
tests playbook for the product to properly configure and start the product.