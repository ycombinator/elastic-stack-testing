'''
Created on Oct 12, 2017

@author: liza
'''


import os
from munch import Munch
from webium import settings
from selenium.webdriver import Chrome, Firefox, Safari, Ie, Edge, PhantomJS


def build_url(d):
    valid_keys = ['protocol', 'host', 'port']
    key_exists = []
    for key in valid_keys:
        key_exists.append(key in d.keys())
    if not all(key_exists):
        raise AttributeError('Valid keys: %s not found in %s' %
                             (valid_keys, str(d.keys())))
    url = '%s://%s:%s' % (d.protocol, d.host, str(d.port))
    return url


def check_browser(browser):
    valid_browsers = [Chrome, Firefox, Safari, Ie, Edge, PhantomJS]
    if browser not in valid_browsers:
        raise AttributeError('Invalid browser: %s' % (browser))
    return browser


browser = Munch()
elasticsearch = Munch()
kibana = Munch()

elasticsearch.protocol = os.getenv('AIT_ELASTICSEARCH_PROTOCOL', 'http')
elasticsearch.host = os.getenv('AIT_ELASTICSEARCH_HOST', 'localhost')
elasticsearch.port = os.getenv('AIT_ELASTICSEARCH_PORT', 9200)
elasticsearch.username = os.getenv('AIT_ELASTICSEARCH_USERNAME', 'elastic')
elasticsearch.password = os.getenv('AIT_ELASTICSEARCH_PASSWORD', 'changeme')
elasticsearch.xpack = os.getenv('AIT_ELASTICSEARCH_XPACK', False)
elasticsearch.url = os.getenv(
    'AIT_ELASTICSEARCH_URL', build_url(elasticsearch))

kibana.protocol = os.getenv('AIT_KIBANA_PROTOCOL', 'http')
kibana.host = os.getenv('AIT_KIBANA_HOST', 'localhost')
kibana.port = os.getenv('AIT_KIBANA_PORT', 5601)
kibana.username = os.getenv('AIT_KIBANA_USERNAME', 'kibana')
kibana.password = os.getenv('AIT_KIBANA_PASSWORD', 'changeme')
kibana.xpack = os.getenv('AIT_KIBANA_XPACK', False)
kibana.url = os.getenv('AIT_KIBANA_URL', build_url(kibana))

browser.type = os.getenv('AIT_BROWSER', Chrome)
settings.driver_class = check_browser(browser.type)
