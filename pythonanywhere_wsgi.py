"""Entrada WSGI segura para a hospedagem gratuita no PythonAnywhere."""

import os
import secrets
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent
PRIVATE_DIR = Path.home() / ".nexo-private"
SECRET_FILE = PRIVATE_DIR / "secret-key"
DATABASE_FILE = PRIVATE_DIR / "financas.db"

PRIVATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
if not SECRET_FILE.exists():
    SECRET_FILE.write_text(secrets.token_urlsafe(64), encoding="utf-8")
    try:
        SECRET_FILE.chmod(0o600)
    except OSError:
        pass

os.environ.setdefault("FINANCE_ENV", "production")
os.environ.setdefault("FINANCE_SECRET", SECRET_FILE.read_text(encoding="utf-8").strip())
os.environ.setdefault("DATABASE_PATH", str(DATABASE_FILE))

if str(PROJECT_DIR) not in sys.path:
    sys.path.insert(0, str(PROJECT_DIR))

from app import app as application  # noqa: E402

