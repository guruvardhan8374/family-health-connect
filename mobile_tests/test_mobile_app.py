import unittest
import time
from appium import webdriver
from appium.options.android import UiAutomator2Options
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.support.ui import WebDriverWait

class FamilyHealthMobileTests(unittest.TestCase):
    def setUp(self):
        # Configure Appium desired capabilities for Android UiAutomator2
        options = UiAutomator2Options()
        options.platform_name = 'Android'
        options.automation_name = 'UiAutomator2'
        options.device_name = 'Android Emulator' # Match your running virtual device name
        
        # Path to the compiled APK file
        options.app = r'C:\Users\Pravi\family_health_connect\family_health_mobile\build\app\outputs\flutter-apk\app-debug.apk'
        
        # Avoid clearing app data to bypass SecurityException on certain devices
        options.no_reset = True
        
        # Set package and main activity names to ensure it runs correctly
        options.set_capability('appPackage', 'com.familyhealth.family_health_mobile')
        options.set_capability('appActivity', '.MainActivity')
        
        # Increase timeouts to give user enough time to click "Install" prompt on physical device screen
        options.set_capability('uiautomator2ServerInstallTimeout', 60000)
        options.set_capability('adbExecTimeout', 60000)
        
        # Initialize connection to the running Appium server (started at port 4723)
        self.driver = webdriver.Remote('http://localhost:4723', options=options)
        self.driver.implicitly_wait(10) # 10 seconds implicit wait

    def test_login_flow(self):
        driver = self.driver
        print("Starting login test...")
        print("Activating application package com.familyhealth.family_health_mobile...")
        driver.activate_app('com.familyhealth.family_health_mobile')
        time.sleep(3)
        try:
            # 0. Dismiss any blocking dialogs/popups left open from previous sessions
            while True:
                dismiss_elements = driver.find_elements(
                    AppiumBy.XPATH, 
                    "//*[@content-desc='Cancel' or @content-desc='Dismiss']"
                )
                if len(dismiss_elements) > 0:
                    print("Found open dialog/overlay. Dismissing it...")
                    dismiss_elements[0].click()
                    time.sleep(2)
                else:
                    break

            # Check if we are already logged in or on the Settings screen
            logout_buttons = driver.find_elements(
                AppiumBy.XPATH,
                "//*[contains(@content-desc, 'Log Out') or contains(@text, 'Log Out')]"
            )
            if len(logout_buttons) > 0:
                print("App is on the Settings screen. Clicking Log Out...")
                logout_buttons[0].click()
                time.sleep(3)
            else:
                home_tabs = driver.find_elements(
                    AppiumBy.XPATH, 
                    "//android.view.View[@content-desc='Home']"
                )
                if len(home_tabs) > 0:
                    print("App is already logged in. Resetting to Home tab and logging out...")
                    home_tabs[0].click()
                    time.sleep(2)
                    
                    # Click the settings button on the Home screen (top-right app bar button)
                    settings_button = driver.find_element(
                        AppiumBy.XPATH, 
                        "//*[contains(@content-desc, 'Settings') or contains(@text, 'Settings')]"
                    )
                    # Settings icon is in the bottom-right corner of the merged app bar element
                    location = settings_button.location
                    size = settings_button.size
                    
                    # Center of settings icon (approx 120px from right edge, 120px from bottom edge in physical pixels)
                    tap_x = int(location['x'] + size['width'] - 120)
                    tap_y = int(location['y'] + size['height'] - 120)
                    print(f"Tapping settings icon at calculated coordinates: ({tap_x}, {tap_y})")
                    
                    # Perform tap using Appium's built-in tap method
                    driver.tap([(tap_x, tap_y)])
                    
                    time.sleep(3) # Give it 3 seconds to animate and load settings screen
                    
                    # Click the Log Out button in Settings
                    logout_button = driver.find_element(
                        AppiumBy.XPATH,
                        "//*[contains(@content-desc, 'Log Out') or contains(@text, 'Log Out')]"
                    )
                    logout_button.click()
                    print("Successfully logged out. Proceeding with login flow test...")
                    time.sleep(3)

            # 1. Wait for the app to load and find the username input field
            # In Flutter apps, text inputs often translate to android.widget.EditText
            print("Waiting for username and password fields to load...")
            WebDriverWait(driver, 15).until(
                lambda d: len(d.find_elements(AppiumBy.CLASS_NAME, "android.widget.EditText")) >= 2
            )
            username_fields = driver.find_elements(AppiumBy.CLASS_NAME, "android.widget.EditText")
            username_field = username_fields[0]
            password_field = username_fields[1]

            # 2. Type login credentials
            print("Entering credentials...")
            print("Tapping username field...")
            username_field.click()
            time.sleep(1)
            print("Typing username...")
            username_field.send_keys("user1")
            time.sleep(1)

            print("Tapping password field...")
            password_field.click()
            time.sleep(1)
            print("Typing password...")
            password_field.send_keys("Pass@123")
            time.sleep(1)

            # Hide the keyboard to restore screen layout and expose the Sign In button
            print("Hiding keyboard...")
            try:
                driver.hide_keyboard()
            except Exception as e:
                print(f"Could not hide keyboard: {e}")
            time.sleep(2)

            # 3. Locate and click the Sign In button
            # We search by text using XPath
            print("Locating Sign In button...")
            sign_in_button = WebDriverWait(driver, 15).until(
                lambda d: d.find_element(
                    AppiumBy.XPATH, 
                    "//android.widget.Button[@content-desc='Sign In' or @text='Sign In']"
                )
            )
            print("Clicking Sign In button...")
            sign_in_button.click()

            # 4. Wait for dashboard screen redirection
            print("Waiting for Dashboard screen to load...")
            dashboard_element = WebDriverWait(driver, 15).until(
                lambda d: d.find_element(
                    AppiumBy.XPATH, 
                    "//*[contains(@content-desc, 'Health Hub') or contains(@text, 'Health Hub')]"
                )
            )
            dashboard_elements = [dashboard_element]
            print("Login test passed successfully!")
        except Exception as e:
            print("DEBUG: Exception occurred.")
            try:
                # Write page source to a file using UTF-8 to prevent UnicodeEncodeError in Windows terminal
                with open("page_source_debug.xml", "w", encoding="utf-8") as f:
                    f.write(driver.page_source)
                print("Saved current page source to page_source_debug.xml")
            except Exception as pe:
                print(f"Could not save page source: {pe}")
            raise e

    def tearDown(self):
        # Shut down driver session
        if self.driver:
            self.driver.quit()

if __name__ == '__main__':
    unittest.main()
