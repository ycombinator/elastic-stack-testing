'''
Created on Sep 26, 2017

@author: liza
'''


from lib.kibana.kibana_basepage import KibanaBasePage
from webium import Find, Finds
from selenium.webdriver.common.by import By
from webium.wait import wait
from selenium.webdriver.remote.webelement import WebElement
from selenium.common.exceptions import NoSuchElementException
import locale


class DiscoverPage(KibanaBasePage):
    '''
    Kibana Discover Page
    '''

    query_hits_label = Find(by=By.CSS_SELECTOR, value='span[data-test-subj="discoverQueryHits"]')
    new_button = Find(by=By.CSS_SELECTOR, value='button[data-test-subj="discoverNewButton"]')
    save_button = Find(by=By.CSS_SELECTOR, value='button[data-test-subj="discoverSaveButton"]')
    open_button = Find(by=By.CSS_SELECTOR, value='button[data-test-subj="discoverOpenButton"]')
    share_button = Find(by=By.CSS_SELECTOR, value='button[data-test-subj="discoverShareButton"]')
    time_picker_button = Find(by=By.CSS_SELECTOR, value='button[data-test-subj="globalTimepickerButton"]')
    
    query_text_field = Find(by=By.CSS_SELECTOR, value='input[ng-model="state.query"]')
    query_search_button = Find(by=By.CSS_SELECTOR, value='button[aria-label="Search"]')
    
    sidebar_item_fields = Finds(by=By.CLASS_NAME, value='sidebar-item')
    
    
    def __init__(self, **kwargs):
        '''
        Constructor
        '''
        super().__init__(**kwargs)
        self.url += '/app/kibana#/discover'
    
    def loaded(self):
        wait(lambda: self.is_element_present('query_hits_label'), 
             waiting_for='query_hits_label to be visible')
   
    def click_pattern(self, pattern):
        sidebar = IndexPatternSideList()
        sidebar.click_pattern(pattern)
      
    def get_query_hits(self):
        hits = self.query_hits_label.text    
        locale.setlocale( locale.LC_ALL, 'en_US.UTF-8' ) 
        return locale.atoi(hits)

    def get_available_fields(self):
        fields = []
        for elem in self.sidebar_item_fields:
            fields.append(elem.text)
        return fields
    
    def get_hits(self, pattern):
        self.open()
        self.wait_for_loading_indicator()
        self.click_pattern(pattern)
        self.wait_for_loading_indicator()
        return self.get_query_hits() 
 
class IndexPatternOptions(WebElement):
    patterns = Finds(by=By.CSS_SELECTOR, value='div[role="option"]')

        
class IndexPatternSideList(KibanaBasePage):

    index_pattern_link = Find(by=By.CLASS_NAME, value='index-pattern')
    index_pattern_dropdown = Find(by=By.CLASS_NAME, value='index-pattern-selection')
    index_pattern_dropdown_options = Find(IndexPatternOptions, by=By.CLASS_NAME, value='index-pattern-selection')
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        wait(lambda: self.is_element_present('index_pattern_link') or 
                     self.is_element_present('index_pattern_dropdown'), 
             waiting_for='Wait for index pattern')
   
    def click_pattern(self, pattern):
        if self.is_element_present('index_pattern_link'):
            if self.index_pattern_link.text == pattern:
                return
        elif self.is_element_present('index_pattern_dropdown'):
            self.index_pattern_dropdown.click()
            for elem in self.index_pattern_dropdown_options.patterns:
                if elem.text == pattern:
                    elem.click()
                    return
        raise NoSuchElementException('Index pattern not found: ' + pattern)
    