import hashlib
import secrets

from pwdlib import PasswordHash


password_hasher = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """تحويل كلمة المرور إلى Hash للتخزين."""
    return password_hasher.hash(password)


def verify_password(password: str, stored_hash: str) -> bool:
    """التحقق من كلمة المرور مقابل الـHash المخزّن."""
    return password_hasher.verify(password, stored_hash)


def generate_session_token() -> str:
    """إنشاء توكن عشوائي جديد لكل جلسة دخول."""
    return secrets.token_urlsafe(32)


def hash_session_token(token: str) -> str:
    """بصمة التوكن التي سنحفظها في قاعدة البيانات."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()