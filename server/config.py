from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


ROOT_DIR = Path(__file__).resolve().parent
ENV_FILE = ROOT_DIR / ".env"


class Settings(BaseSettings):
    cloudflare_api_token: str
    cloudflare_account_id: str
    cloudflare_zone_id: str
    base_domain: str = "aghaiofir.win"

    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()