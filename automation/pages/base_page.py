from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from automation.config.config import BASE_URL, EXPLICIT_WAIT
from automation.utils.logger import logger

class BasePage:
    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, EXPLICIT_WAIT)

    def navigate_to(self, path=""):
        full_url = f"{BASE_URL.rstrip('/')}/{path.lstrip('/')}"
        logger.info(f"Navigating to: {full_url}")
        self.driver.get(full_url)

    def find_element(self, locator):
        return self.wait.until(EC.presence_of_element_located(locator))

    def find_elements(self, locator):
        return self.wait.until(EC.presence_of_all_elements_located(locator))

    def click(self, locator):
        element = self.wait.until(EC.element_to_be_clickable(locator))
        element.click()

    def type_text(self, locator, text):
        element = self.find_element(locator)
        element.clear()
        element.send_keys(text)

    def get_text(self, locator):
        element = self.find_element(locator)
        return element.text

    def is_displayed(self, locator):
        try:
            return self.find_element(locator).is_displayed()
        except (TimeoutException, NoSuchElementException):
            return False

    def get_title(self):
        return self.driver.title

    def get_current_url(self):
        return self.driver.current_url

    def get_console_logs(self):
        try:
            return self.driver.get_log("browser")
        except Exception:
            return []
