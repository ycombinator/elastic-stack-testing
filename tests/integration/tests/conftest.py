'''
Created on Oct 3, 2017

@author: liza
'''


import pytest
from webium.driver import close_driver
from lib.api_session import ApiSession
from lib import config


@pytest.fixture(scope='session', autouse=False)
def es_api_session(request):
    api = ApiSession(cfg=config.elasticsearch)
    return api


@pytest.fixture(scope='session', autouse=True)
def teardown(request):
    @request.addfinalizer
    def tear_down():
        close_driver()
