"""
User model - represents users table
"""
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class User(Base):
    """User model with one-to-many relationship to todos"""
    
    __tablename__ = "users"
    
    # Primary Key
    id = Column(Integer, primary_key=True, index=True)
    
    # User fields
    name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, nullable=False, index=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationship: One user has many todos
    todos = relationship(
        "Todo",
        back_populates="owner",
        cascade="all, delete-orphan"
    )
    
    # Relationship: One user has many comments
    comments = relationship(
        "Comment",
        back_populates="author",
        cascade="all, delete-orphan"
    )
    
    def __repr__(self):
        return f"<User(id={self.id}, email='{self.email}')>"
