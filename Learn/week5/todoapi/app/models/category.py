"""
Category model - represents categories table
"""
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class Category(Base):
    """Category model with one-to-many relationship to todos"""
    
    __tablename__ = "categories"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationship: One category has many todos
    todos = relationship(
        "Todo",
        back_populates="category"
    )
    
    def __repr__(self):
        return f"<Category(id={self.id}, name='{self.name}')>"
