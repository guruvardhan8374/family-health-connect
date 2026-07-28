import os
from datetime import datetime
from automation.config.config import SCREENSHOTS_DIR
from automation.utils.logger import logger

def capture_screenshot(driver, test_id, status="FAIL"):
    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        filename = f"{status}_{test_id}_{timestamp}.png"
        filepath = os.path.join(SCREENSHOTS_DIR, filename)
        
        if driver:
            driver.save_screenshot(filepath)
            logger.info(f"Captured screenshot: {filepath}")
            return filepath
    except Exception as e:
        logger.error(f"Failed to capture screenshot for {test_id}: {e}")
    return None
