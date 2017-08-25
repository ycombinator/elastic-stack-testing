'''
Created on Aug 21, 2017

@author: liza.dayoub@elastic.co
'''

from subprocess import Popen, PIPE
import os
import shutil

def create_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)
    if os.path.isdir(directory):
        return True
    return False

def run(command):
    process = Popen(command, stdout=PIPE, shell=True)
    while True:
        line = process.stdout.readline().rstrip()
        if not line:
            break
        yield line

p = Popen('VBoxManage list runningvms', shell=True, stdout=PIPE)
if len(p.stdout.readlines()) > 0:
    print('Another VM is running')
    exit(1)

rootdir  = os.environ.get('WORKSPACE', '/tmp')
vagrant_file = os.environ.get('AIT_ROOTDIR') + '/vm/vagrant/Vagrantfile'

default_box = 'elastic/ubuntu-16.04-x86_64'   

if not os.environ.get('VAGRANT_BOX'):
    os.environ['VAGRANT_BOX'] = default_box 
    
box =  os.environ['VAGRANT_BOX'] 

if not os.environ.get('VAGRANT_DIR'):
    os.environ['VAGRANT_DIR'] = rootdir + '/' + os.path.basename(os.environ['VAGRANT_BOX'])

vagrant_dir = os.environ['VAGRANT_DIR']

if not create_dir(vagrant_dir):
    print(vagrant_dir + ' is not a directory.')
    exit(1)

shutil.copy2(vagrant_file, vagrant_dir) 

os.chdir(vagrant_dir)
for output in run('vagrant up'):
    print(output)

exit(0)

