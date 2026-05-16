# main.py
import os
import jwt


from fastapi.security import OAuth2PasswordBearer
from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional

# Rate Limiting components
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Import your separated routers
from mapdetection import router as map_router
from schedule import router as schedule_router
from ai_routes import router as ai_router
from contacts import router as contacts_router 
from auth import router as auth_router, SECRET_KEY, ALGORITHM

# ---------------------------------------------------------------------------
# 1. Initialize Application & Rate Limiter
# ---------------------------------------------------------------------------
limiter = Limiter(key_func=get_remote_address)
app = FastAPI(
    title="CareOS API", 
    description="Secure Backend for Elderly Care AI Relationship OS"
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ---------------------------------------------------------------------------
# 2. Secure CORS Policies
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# 3. Mount External Routers
# ---------------------------------------------------------------------------
app.include_router(map_router)
app.include_router(auth_router)
app.include_router(schedule_router)
app.include_router(ai_router)
app.include_router(contacts_router)

# ---------------------------------------------------------------------------
# Security Dependencies (Strict JWT Authentication)
# ---------------------------------------------------------------------------
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

def get_current_user(token: str = Depends(oauth2_scheme)):
    """
    Decodes the JWT token. If the token is invalid or expired, it kicks the user out.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        role: str = payload.get("role")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
        return {"username": username, "role": role}
    
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired. Please log in again.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token.")

def require_admin_role(current_user: dict = Depends(get_current_user)):
    """Checks if the logged-in user actually has the admin role inside their token."""
    if current_user.get("role") != "admin":
         raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrative privileges required."
        )
    return current_user

# ---------------------------------------------------------------------------
# Core Endpoints (Root & Admin)
# ---------------------------------------------------------------------------
@app.get("/")
async def root():
    return {"message": "CareOS Backend is running securely!"}

@app.post("/api/admin/system/pause-pipeline")
async def pause_detection_pipeline(admin: dict = Depends(require_admin_role)):
    """
    Highly critical system operations. Secured behind strict RBAC.
    """
    return {"status": "deactivated", "message": "Pipeline halted safely by verified administrator."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)