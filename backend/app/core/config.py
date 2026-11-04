from functools import lru_cache
from pathlib import Path
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BACKEND_DIR / '.env', extra='ignore')
    app_env: str = 'development'
    memora_secret: str = ''
    database_url: str = 'sqlite:///./data/memora.db'
    media_root: str = './data/media'
    max_upload_mb: int = 50
    allowed_origins: str = ''
    meta_api_key: str = ''
    meta_api_base: str = 'https://api.meta.ai/v1'
    muse_spark_model: str = 'muse-spark-1.3'
    yolo_enabled: bool = False
    yolo_model_path: str = ''
    ocr_enabled: bool = False
    barcode_enabled: bool = True
    camera_ingestion_enabled: bool = False
    camera_sample_interval_seconds: int = 10
    camera_streams_json: str = Field(
        default='{}',
        validation_alias='MEMORA_CAMERA_STREAMS_JSON',
    )
    smtp_host: str = ''
    smtp_port: int = 587
    smtp_username: str = ''
    smtp_password: str = ''
    smtp_from_email: str = ''
    smtp_starttls: bool = True

    @property
    def password_reset_email_configured(self):
        return bool(self.smtp_host and self.smtp_from_email)

    @property
    def origins(self): return [x.strip() for x in self.allowed_origins.split(',') if x.strip()]
    @property
    def media_path(self):
        p = Path(self.media_root).resolve(); p.mkdir(parents=True, exist_ok=True); return p
    def validate_security(self):
        if len(self.memora_secret) < 32:
            raise RuntimeError('Set MEMORA_SECRET to at least 32 random characters in .env.')
        if self.app_env == 'production' and self.memora_secret.startswith('CHANGE-ME'):
            raise RuntimeError('Replace the example MEMORA_SECRET before production.')
@lru_cache
def get_settings(): return Settings()
