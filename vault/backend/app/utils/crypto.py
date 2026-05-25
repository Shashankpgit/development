from cryptography.fernet import Fernet
from app.config import VAULT_ENCRYPTION_KEY

_fernet = Fernet(VAULT_ENCRYPTION_KEY.encode())


def encrypt(value: str) -> str:
    return _fernet.encrypt(value.encode()).decode()


def decrypt(value: str) -> str:
    return _fernet.decrypt(value.encode()).decode()
