"""
Tag model for many-to-many relationship with todos
"""
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
from app.models.todo import todo_tags


class Tag(Base):
    """Tag model"""
    
    __tablename__ = "tags"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Many-to-many relationship with todos
    todos = relationship(
        "Todo",
        secondary=todo_tags,
        back_populates="tags"
    )
    
    def __repr__(self):
        return f"<Tag(id={self.id}, name='{self.name}')>"
