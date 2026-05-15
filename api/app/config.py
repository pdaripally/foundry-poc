from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    github_token: str
    github_owner: str
    github_repo: str
    github_ref: str = "main"
    allowed_origins: str = "http://localhost:3000"

    @property
    def origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",")]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
