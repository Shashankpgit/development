"""All configuration in one place, read from environment variables.

WHY not hardcode the database URL? Because the SAME container image has to run
on your laptop, in staging and in EKS. If the URL lives in the code, each
environment needs its own image. If it lives in the environment, one image
works everywhere and Helm supplies the values. That is the "config" rule of
the 12-factor app method.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # env_file is a LOCAL convenience only. In Kubernetes there is no .env
    # file -- values arrive as real env vars from a ConfigMap/Secret.
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # postgresql+psycopg:// -> dialect + driver.
    #   postgresql = which SQL dialect to speak
    #   psycopg    = which Python library actually opens the socket (psycopg3)
    database_url: str = "postgresql+psycopg://shop_user:shop_pass@localhost:5432/shop_db"

    # The browser will not let JavaScript on :5173 call an API on :8000 unless
    # the API says it is allowed. This list is that permission. See main.py.
    cors_origins: str = "http://localhost:5173,http://127.0.0.1:5173"

    # In EKS you run migrations as a Job, not on app boot. Locally, letting the
    # app create its own tables removes a setup step. Hence the switch.
    auto_create_tables: bool = True

    app_name: str = "Shop API"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
