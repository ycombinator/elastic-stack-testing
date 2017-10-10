'''
Created on Oct 1, 2017

@author: liza
'''


from lib.kibana.management.index_patterns_page import IndexPatternsPage
from lib.kibana.discover.discover_page import DiscoverPage
from lib.elasticsearch.api.bulk_api import ElasticsearchBulkApi
from tests.data.defs import ES_BANK_ACCOUNTS
from http import HTTPStatus

 
class TestClass:
    
    def test_elasticsearch_kibana(self, api_session):
        esapi = ElasticsearchBulkApi(api_session)
        data_file =  ES_BANK_ACCOUNTS['data_file']
        data_index =  ES_BANK_ACCOUNTS['data_index']
        data_type = ES_BANK_ACCOUNTS['data_type']
        data_entries = ES_BANK_ACCOUNTS['data_entries']
        response = esapi.post(file=data_file, 
                              index=data_index, 
                              doc_type=data_type)
        assert response.status_code == HTTPStatus.OK
        index_patterns_page = IndexPatternsPage()
        assert index_patterns_page.create_index(data_index + '*', IndexPatternsPage.TIME_FILTER_NONE)
        discover_page = DiscoverPage()
        assert discover_page.get_hits(data_index + '*') == data_entries

    def test_filebeat_elasticsearch_kibana(self):
        index_patterns_page = IndexPatternsPage()
        assert index_patterns_page.create_index('filebeat-*', IndexPatternsPage.TIME_FILTER_TIMESTAMP)
        discover_page = DiscoverPage()
        assert discover_page.get_hits('filebeat-*') > 0
