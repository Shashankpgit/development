from dotenv import load_dotenv
import os

load_dotenv()

APP_ENV = os.getenv("APP_ENV", "development")
DATABASE_URL = os.getenv("DATABASE_URL", "")
VAULT_ENCRYPTION_KEY = os.getenv("VAULT_ENCRYPTION_KEY", "")
