from fastapi import APIRouter
from app.database import check_db_connection

router = APIRouter()


@router.get("/health")
def health_check():
    db_status = "connected" if check_db_connection() else "unreachable"
    return {"status": "ok", "version": "0.1.0", "database": db_status}
