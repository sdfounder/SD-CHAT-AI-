import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

    environment: str = Field(default="development")
    port: int = Field(default=8000)
    debug: bool = Field(default=True)

    # Base de données PostgreSQL (Supabase SD-DEV)
    database_url: str = Field(
        default="postgresql://postgres.ryvmacsmfvllhgbqbnkb:sekoudiaby224@aws-1-eu-west-1.pooler.supabase.com:5432/postgres"
    )

    # Supabase Infrastructure
    supabase_url: str = Field(default="https://ryvmacsmfvllhgbqbnkb.supabase.co")
    supabase_anon_key: str = Field(default="")
    supabase_service_role_key: str = Field(default="")
    supabase_jwt_secret: str = Field(default="super-secret-jwt-token-sd-dev-2026")

    # Moteurs IA (SD AI Gateway)
    gemini_api_key: str = Field(default="")
    gemini_model: str = Field(default="gemini-3.6-flash")
    openai_api_key: str = Field(default="")
    anthropic_api_key: str = Field(default="")
    xai_api_key: str = Field(default="")
    openrouter_api_key: str = Field(default="")
    deepseek_api_key: str = Field(default="")

    # Monétisation & Billing Stripe
    stripe_secret_key: str = Field(default="")
    stripe_webhook_secret: str = Field(default="")

    # CORS
    cors_origins: List[str] = Field(default=["*"])


settings = Settings()
