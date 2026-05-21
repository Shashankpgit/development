# Import all models here so Base.metadata always has the full picture.
# Any model not imported here risks its table not being created by create_all().
from app.models.user import User
from app.models.note import Note
from app.models.password_entry import PasswordEntry
