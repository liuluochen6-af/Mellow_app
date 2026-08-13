from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    database_url: str
    app_env: str = "development"
    sms_access_key_id: str = ""
    sms_access_key_secret: str = ""
    sms_sign_name: str = ""
    sms_template_code: str = ""
    sms_international_sender_id: str = "Mellow"
    sms_international_message_template: str = "Your Mellow verification code is {code}. It expires in 5 minutes."
    sms_debug_return_code: bool = False
    apple_client_id: str = "com.foodcheckin.app"
    secret_key: str = "dev-secret-key-change-in-production"

settings = Settings()
