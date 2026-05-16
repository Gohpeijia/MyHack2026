# auth.py
import datetime
import jwt
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

router = APIRouter(
    prefix="/api/auth",
    tags=["Authentication"]
)

# ---------------------------------------------------------------------------
# Security Configuration
# ---------------------------------------------------------------------------
# In production, put this inside your .env file!
SECRET_KEY = "super_secret_hackathon_key_do_not_share"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # Token valid for 24 hours

# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------
class UserSignup(BaseModel):
    username: str
    password: str
    role: str  # e.g., "family", "volunteer", "admin"

class UserLogin(BaseModel):
    username: str
    password: str

# ---------------------------------------------------------------------------
# Mock Database (Replace with Firebase or real DB later)
# ---------------------------------------------------------------------------
# We store plain passwords here ONLY for the hackathon demo. 
# Normally, you must hash these using bcrypt!
MOCK_USERS_DB = {
    "admin123": {"password": "password123", "role": "admin"},
    "family_peyton": {"password": "password123", "role": "family"},
    "volunteer_siti": {"password": "password123", "role": "volunteer"},
}

# ---------------------------------------------------------------------------
# Helper Function: Create Token
# ---------------------------------------------------------------------------
def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.datetime.utcnow() + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@router.post("/signup")
async def register_user(user: UserSignup):
    if user.username in MOCK_USERS_DB:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # Save to mock database
    MOCK_USERS_DB[user.username] = {"password": user.password, "role": user.role}
    return {"message": "User created successfully", "username": user.username}

@router.post("/login")
async def login_user(user: UserLogin):
    # 1. Verify user exists and password matches
    db_user = MOCK_USERS_DB.get(user.username)
    if not db_user or db_user["password"] != user.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )
    
    # 2. Generate JWT Token containing their username and role
    access_token = create_access_token(
        data={"sub": user.username, "role": db_user["role"]}
    )
    
    return {
        "access_token": access_token, 
        "token_type": "bearer",
        "role": db_user["role"],
        "message": f"Welcome back, {user.username}!"
    } 