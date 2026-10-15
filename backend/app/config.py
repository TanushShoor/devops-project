from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    app_name: str = "Study Planner API"
    database_url: str = "postgresql+psycopg://studyplanner:studyplanner@localhost:5432/studyplanner"
    model_config = SettingsConfigDict(env_file=".env", env_prefix="", extra="ignore")

settings = Settings()
