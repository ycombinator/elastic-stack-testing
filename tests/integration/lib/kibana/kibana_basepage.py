'''
Created on Sep 23, 2017

@author: liza
'''


from selenium.webdriver.common.by import By
from webium import BasePage, Find
from webium import settings
from selenium.webdriver import Chrome
from webium.wait import wait


class KibanaBasePage(BasePage):
    
    # Move to config 
    url = 'http://localhost:5601'
    # PATH variable is set to unzip dir to chromedriver 
    settings.driver_class = Chrome
    # -- done move to config
    
    loading_indicator = Find(by=By.CSS_SELECTOR, value='div[data-test-subj="globalLoadingIndicator"]')
    
    def __init(self, **kwargs):
        super().__init__(**kwargs)
        
    def wait_for_loading_indicator(self, timeout=5):
        try:
            wait(lambda: self.is_element_present('loading_indicator') is True, waiting_for='Loading indicator is displayed', timeout_seconds=timeout)
        except:
            pass
        wait(lambda: self.is_element_present('loading_indicator') is False, waiting_for='Loading indicator is not displayed', timeout_seconds=timeout)
