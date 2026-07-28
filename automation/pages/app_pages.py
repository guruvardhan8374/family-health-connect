from selenium.webdriver.common.by import By
from automation.pages.base_page import BasePage

class LoginPage(BasePage):
    USERNAME_INPUT = (By.ID, "username")
    PASSWORD_INPUT = (By.ID, "password")
    LOGIN_BUTTON = (By.XPATH, "//button[@type='submit']")
    ERROR_ALERT = (By.CLASS_NAME, "text-red-500")

    def login(self, username, password):
        self.type_text(self.USERNAME_INPUT, username)
        self.type_text(self.PASSWORD_INPUT, password)
        self.click(self.LOGIN_BUTTON)

class RegisterPage(BasePage):
    USERNAME_INPUT = (By.ID, "username")
    EMAIL_INPUT = (By.ID, "email")
    PASSWORD_INPUT = (By.ID, "password")
    CONFIRM_PASSWORD_INPUT = (By.ID, "confirm_password")
    REGISTER_BUTTON = (By.XPATH, "//button[@type='submit']")

class DashboardPage(BasePage):
    WELCOME_HEADER = (By.XPATH, "//h1 | //h2")
    HEALTH_SUMMARY_CARD = (By.XPATH, "//div[contains(@class, 'card') or contains(@class, 'bg-white')]")
    SIDEBAR_NAV = (By.TAG_NAME, "nav")

class FamilyPage(BasePage):
    CREATE_CIRCLE_BUTTON = (By.XPATH, "//button[contains(text(), 'Create') or contains(text(), 'Circle')]")
    DELETE_CIRCLE_BUTTON = (By.XPATH, "//button[contains(text(), 'Delete Circle')]")
    ACTIVE_CIRCLE_SELECT = (By.TAG_NAME, "select")

class HealthPage(BasePage):
    ADD_VITALS_BUTTON = (By.XPATH, "//button[contains(text(), 'Add') or contains(text(), 'Vitals')]")
    HEART_RATE_CARD = (By.XPATH, "//*[contains(text(), 'Heart Rate')]")

class SettingsPage(BasePage):
    PROFILE_TAB = (By.XPATH, "//*[contains(text(), 'Profile')]")
    USERNAME_INPUT = (By.NAME, "username")
    SAVE_BUTTON = (By.XPATH, "//button[contains(text(), 'Save')]")

class ChatPage(BasePage):
    MESSAGE_INPUT = (By.XPATH, "//input[@placeholder='Type a message...' or @type='text']")
    SEND_BUTTON = (By.XPATH, "//button[@type='submit']")
    CONVERSATION_ITEM = (By.XPATH, "//div[contains(@class, 'cursor-pointer')]")

class EmergencyPage(BasePage):
    TRIGGER_SOS_BUTTON = (By.XPATH, "//button[contains(text(), 'SOS') or contains(text(), 'Emergency')]")
    ACTIVE_ALERTS_CARD = (By.XPATH, "//*[contains(text(), 'Active Alerts')]")

class NotificationsPage(BasePage):
    NOTIFICATION_LIST = (By.XPATH, "//div[contains(@class, 'notification')]")
    MARK_ALL_READ = (By.XPATH, "//button[contains(text(), 'Mark all as read')]")
