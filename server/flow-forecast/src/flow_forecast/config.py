# pydantic settings to load .env file
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Config(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    log_level: str = Field(default="INFO")
    port: int = Field(default=8000)
    host: str = Field(default="0.0.0.0")
    server_url: str = Field(default="http://localhost:8000")

config = Config()