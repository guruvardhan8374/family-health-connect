from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.chrome.service import Service as ChromeService
from webdriver_manager.chrome import ChromeDriverManager
from automation.config.config import HEADLESS, WINDOW_SIZE
from automation.utils.logger import logger

def get_driver():
    logger.info("Initializing Selenium Chrome WebDriver...")
    options = ChromeOptions()
    
    if HEADLESS:
        options.add_argument("--headless=new")
    
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-extensions")
    options.add_argument("--remote-allow-origins=*")
    options.add_argument(f"--window-size={WINDOW_SIZE[0]},{WINDOW_SIZE[1]}")
    options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

    try:
        service = ChromeService(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=options)
    except Exception as e:
        logger.warning(f"ChromeDriverManager failed ({e}). Falling back to system ChromeDriver...")
        driver = webdriver.Chrome(options=options)

    driver.implicitly_wait(10)
    driver.set_page_load_timeout(30)
    logger.info("Chrome WebDriver initialized successfully.")
    return driver
