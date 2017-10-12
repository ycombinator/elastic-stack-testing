'''
Created on Oct 1, 2017

@author: liza
'''


from lib.kibana.management.index_patterns_page import IndexPatternsPage
from lib.kibana.discover.discover_page import DiscoverPage
from lib.elasticsearch.api.bulk_api import ElasticsearchBulkApi
from tests.data import info
from http import HTTPStatus


class TestClass:

    def test_elasticsearch_kibana(self, es_api_session):
        """ Load bank account information in Elasticsearch, verify number of hits in Kibana matches number of entries """
        data = info.es_bank_accounts
        kibana_index = data.index + '*'
        esapi = ElasticsearchBulkApi(es_api_session)
        response = esapi.post(file=data.file,
                              index=data.index,
                              doc_type=data.type)
        index_patterns_page = IndexPatternsPage()
        index_patterns_page.create_index(
            kibana_index, IndexPatternsPage.TIME_FILTER_NONE)
        discover_page = DiscoverPage()
        assert discover_page.get_hits(kibana_index) == data.entries

    def test_filebeat_elasticsearch_kibana(self):
        """ Filebeat verify number of hits in Kibana are greater than zero """
        kibana_index = 'filebeat-*'
        index_patterns_page = IndexPatternsPage()
        index_patterns_page.create_index(
            kibana_index, IndexPatternsPage.TIME_FILTER_TIMESTAMP)
        discover_page = DiscoverPage()
        assert discover_page.get_hits(kibana_index) > 0
