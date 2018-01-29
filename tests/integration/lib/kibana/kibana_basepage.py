'''
Created on Sep 23, 2017

@author: Liza Dayoub
'''


from selenium.webdriver.common.by import By
from webium import BasePage, Find
from webium.wait import wait
from lib import config


class KibanaBasePage(BasePage):

    loading_indicator = Find(by=By.CSS_SELECTOR, value='div[data-test-subj="globalLoadingIndicator"]')

    def __init__(self, url=config.kibana.url, **kwargs):
        self.url = url.strip('/')
        super().__init__(**kwargs)

    def wait_for_loading_indicator(self, timeout=5):
        try:
            wait(lambda: self.is_element_present('loading_indicator') is True,
                 waiting_for='Loading indicator is displayed', timeout_seconds=timeout)
        except:
            pass
        wait(lambda: self.is_element_present('loading_indicator') is False,
             waiting_for='Loading indicator is not displayed', timeout_seconds=timeout)
