'''
Created on Sep 29, 2017

@author: liza
'''


import requests
from requests.packages.urllib3 import disable_warnings
from requests.packages.urllib3.exceptions import InsecureRequestWarning

class ApiSession(object):
    '''
    classdocs
    '''


    def __init__(self, url, username=None, password=None, insecure=True):
        '''
        Constructor
        '''
        self.url = url
        self.username = username
        self.password = password
        self.session = requests.Session()
        if insecure:
            disable_warnings(InsecureRequestWarning)
            self.session.verify = False
        if self.username and self.password:
            self.session.auth = (self.username, self.password)

    def delete(self, path, **kwargs):
        response = self.session.delete(self.url + path, **kwargs)
        response.raise_for_status()
        return response
    
    def get(self, path, **kwargs):
        response = self.session.get(self.url + path, **kwargs)
        response.raise_for_status()
        return response
    
    def post(self, path, **kwargs):
        response = self.session.post(self.url + path, **kwargs)
        response.raise_for_status()
        return response
    
    def put(self, path, **kwargs):
        response = self.session.put(self.url + path, **kwargs)
        response.raise_for_status()
        return response
    
    def update_headers(self, info):
        self.session.headers.update(info)
