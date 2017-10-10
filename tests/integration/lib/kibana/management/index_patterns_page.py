'''
Created on Sep 25, 2017

@author: Liza Dayoub
'''


from lib.kibana.kibana_basepage import KibanaBasePage
from webium import Find
from selenium.webdriver.common.by import By
from webium.wait import wait
from webium.controls.select import Select
from webium.driver import get_driver
import re
from lib.ait_exceptions import IndexPatternDoesNotExist


class IndexPatternsPage(KibanaBasePage):
    '''
    Kibana Management Index Patterns Page
    '''
    
    TIME_FILTER_TIMESTAMP = '@timestamp'
    TIME_FILTER_NONE = 'I don\'t want to use the Time Filter'

    index_pattern_field = Find(by=By.CSS_SELECTOR, value='input[data-test-subj="createIndexPatternNameInput"]')
    advanced_options_link = Find(by=By.LINK_TEXT, value='advanced options')
    index_pattern_id_field = Find(by=By.CSS_SELECTOR, value='input[data-test-subj="createIndexPatternIdInput"]')
    
    time_filter_dropdown = Find(Select, by=By.CSS_SELECTOR, value='select[data-test-subj="createIndexPatternTimeFieldSelect"]')
    refresh_fields_link = Find(by=By.LINK_TEXT, value='refresh fields')
    
    create_button = Find(by=By.CSS_SELECTOR, value='button[data-test-subj="createIndexPatternCreateButton"]')

    set_default_index_button = Find(by=By.CSS_SELECTOR, value='button[data-test-subj="setDefaultIndexPatternButton"]')
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.url += '/app/kibana#/management/kibana/index'

    def loaded(self):
        wait(lambda: self.is_element_present('index_pattern_field') is True, waiting_for='Index pattern field to be visible')
        
    def click_advanced_options(self):
        self.advanced_options_link.click()
    
    def click_create_button(self):
        self.create_button.click()
        
    def click_refresh_fields(self):
        self.refresh_fields_link.click()
    
    def click_set_as_default_index(self):
        self.set_default_index_button.click()

    def enter_index_pattern(self, pattern):
        self.index_pattern_field.clear()
        self.index_pattern_field.send_keys(pattern)
     
    def enter_index_pattern_id(self, pattern_id):
        if not self.is_element_present('index_pattern_id_field'):
            self.click_advanced_options()
        self.index_pattern_id_field.clear()
        self.index_pattern_id_field.send_keys(pattern_id)
       
    def get_index_id_from_url(self):
        current_url = get_driver().current_url
        regex = re.compile('/indices/(.+)\?')
        match = regex.search(current_url)
        if hasattr(match, 'groups'):
            return match.group(1)
        return None

    def select_time_filter(self, selfilter):
        self.time_filter_dropdown.select_by_visible_text(selfilter)

    def create_index(self, pattern_name, time_filter, pattern_id=None):
        self.open()
        self.loaded()
        self.enter_index_pattern(pattern_name)
        if pattern_id:
            self.enter_index_pattern_id(pattern_id)
        self.select_time_filter(time_filter)
        self.click_create_button()
        self.wait_for_loading_indicator()
        wait(lambda: self.get_index_id_from_url() is not None, waiting_for='Index pattern field to be visible', timeout_seconds=5)
        index_id = self.get_index_id_from_url()
        if not index_id:
            raise IndexPatternDoesNotExist('Index pattern not created')
        return index_id
