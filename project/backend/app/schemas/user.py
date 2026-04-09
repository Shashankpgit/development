"""
User schemas for requests and responses
"""
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional
from datetime import datetime
import re


class UserBase(BaseModel):
    """Base user schema"""
    email: EmailStr
    full_name: Optional[str] = None


class UserCreate(UserBase):
    """Schema for user registration"""
    password: str = Field(..., min_length=8, max_length=100)
    
    @validator('password')
    def validate_password(cls, v):
        """
        Validate password strength
        
        Requirements:
        - At least 8 characters
        - At least one uppercase letter
        - At least one lowercase letter
        - At least one digit
        """
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        
        if not re.search(r'[A-Z]', v):
            raise ValueError('Password must contain at least one uppercase letter')
        
        if not re.search(r'[a-z]', v):
            raise ValueError('Password must contain at least one lowercase letter')
        
        if not re.search(r'\d', v):
            raise ValueError('Password must contain at least one digit')
        
        return v


class UserLogin(BaseModel):
    """Schema for user login"""
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    """Schema for user update"""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    password: Optional[str] = Field(None, min_length=8, max_length=100)


class UserResponse(UserBase):
    """Public user response (no sensitive data)"""
    id: int
    is_active: bool
    is_verified: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserInDB(UserResponse):
    """User as stored in database"""
    hashed_password: str
    is_superuser: bool