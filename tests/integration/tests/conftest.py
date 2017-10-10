'''
Created on Oct 3, 2017

@author: liza
'''


import pytest
from webium.driver import close_driver
from lib.api_session import ApiSession

 
@pytest.fixture(scope='session', autouse=False)
def api_session(request):
    # TODO: url should be in config
    api = ApiSession('http://localhost:9200')
    return api
        
@pytest.fixture(scope='session', autouse=True)
def teardown(request):
    @request.addfinalizer
    def tear_down():
        close_driver()