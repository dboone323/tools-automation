#!/usr/bin/env python3
"""
Working JWT Auth for Phase 3 Testing
"""

import jwt
import os
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Dict, Optional, List

class JWTAuthManager:
    def __init__(self, secret_key: str = None):
        self.secret_key = secret_key or os.getenv("JWT_SECRET", "dev_secret_key_123")
        self.algorithm = "HS256"
        self.token_expiry = timedelta(hours=24)
        
        # Simple user store for testing
        self.users = {
            "admin": {
                "password_hash": self._hash_password("admin"),
                "role": "admin",
                "permissions": ["read", "write", "admin"]
            },
            "user": {
                "password_hash": self._hash_password("user"),
                "role": "user", 
                "permissions": ["read"]
            }
        }
    
    def _hash_password(self, password: str) -> str:
        return hashlib.sha256(password.encode()).hexdigest()
    
    def authenticate_user(self, username: str, password: str) -> Optional[Dict]:
        user = self.users.get(username)
        if user and user["password_hash"] == self._hash_password(password):
            return {
                "username": username,
                "role": user["role"],
                "permissions": user["permissions"]
            }
        return None
    
    def generate_token(self, username: str, role: str, permissions: List[str]) -> str:
        payload = {
            "username": username,
            "role": role,
            "permissions": permissions,
            "exp": datetime.now(timezone.utc) + self.token_expiry,
            "iat": datetime.now(timezone.utc)
        }
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
    
    def verify_token(self, token: str) -> Optional[Dict]:
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[self.algorithm])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
    
    def login(self, username: str, password: str) -> Optional[str]:
        user = self.authenticate_user(username, password)
        if user:
            return self.generate_token(
                user["username"],
                user["role"], 
                user["permissions"]
            )
        return None
    
    def get_status(self):
        return {
            "total_users": len(self.users),
            "algorithm": self.algorithm,
            "token_expiry_hours": self.token_expiry.total_seconds() / 3600
        }

# Global instance
_auth_manager = None

def get_auth_manager():
    global _auth_manager
    if _auth_manager is None:
        _auth_manager = JWTAuthManager()
    return _auth_manager

def main():
    auth = get_auth_manager()
    
    # Test login
    token = auth.login("admin", "admin")
    if token:
        print(f"Login successful! Token generated")
        
        # Test verification
        payload = auth.verify_token(token)
        if payload:
            print(f"Token valid for user: {payload['username']}")
        else:
            print("Token verification failed")
    else:
        print("Login failed")
    
    print("Auth status:", auth.get_status())

if __name__ == "__main__":
    main()
