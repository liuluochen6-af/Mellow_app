from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    sms_access_key_id: str = ""
    sms_access_key_secret: str = ""
    sms_sign_name: str = ""
    sms_template_code: str = ""
    secret_key: str = "dev-secret-key-change-in-production"

    class Config:
        env_file = ".env"


settings = Settings()
