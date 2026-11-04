import time, jwt
from passlib.context import CryptContext
from fastapi import HTTPException
from app.core.config import get_settings
_pwd = CryptContext(schemes=['pbkdf2_sha256'], deprecated='auto')
def hash_password(password: str) -> str:
    if len(password) < 10: raise ValueError('Password must contain at least 10 characters.')
    return _pwd.hash(password)
def verify_password(password: str, hashed: str) -> bool: return _pwd.verify(password, hashed)
def create_token(user_id: str, remember_me: bool = False) -> str:
    now=int(time.time()); s=get_settings()
    lifetime = 30 * 24 * 3600 if remember_me else 3600
    return jwt.encode({'sub':user_id,'iat':now,'exp':now+lifetime}, s.memora_secret, algorithm='HS256')
def decode_token(token: str) -> str:
    try: return str(jwt.decode(token,get_settings().memora_secret,algorithms=['HS256'])['sub'])
    except Exception: raise HTTPException(401,'Invalid or expired token')
