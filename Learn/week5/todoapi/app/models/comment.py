"""
Comment model - represents comments table
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class Comment(Base):
    """Comment model with relationship to todos and users"""
    
    __tablename__ = "comments"
    
    id = Column(Integer, primary_key=True, index=True)
    text = Column(String(500), nullable=False)
    
    # Foreign Keys
    todo_id = Column(Integer, ForeignKey("todos.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    todo = relationship("Todo", back_populates="comments")
    author = relationship("User", back_populates="comments")
    
    def __repr__(self):
        return f"<Comment(id={self.id}, todo_id={self.todo_id}, user_id={self.user_id})>"
