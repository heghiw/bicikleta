import os
import uuid
import aiofiles
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from database import get_db
from auth import hash_password, verify_password, create_access_token, get_current_user
import models
import schemas

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "data/uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

router = APIRouter(prefix="/auth", tags=["auth"])


async def _save_upload(file: UploadFile, subfolder: str) -> str:
    """Save an uploaded file and return its relative URL path."""
    dest = os.path.join(UPLOAD_DIR, subfolder)
    os.makedirs(dest, exist_ok=True)
    ext = os.path.splitext(file.filename or "")[-1] or ".bin"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(dest, filename)
    async with aiofiles.open(filepath, "wb") as f:
        await f.write(await file.read())
    return f"/uploads/{subfolder}/{filename}"


@router.post("/register", response_model=schemas.UserOut, status_code=status.HTTP_201_CREATED)
async def register(
    name: str,
    email: str,
    password: str,
    id_photo: UploadFile = File(..., description="Government-issued ID image"),
    face_photo: UploadFile = File(..., description="Selfie / face photo"),
    db: Session = Depends(get_db),
):
    """Register a new user with ID and face photo uploads.
    Account is created in unverified state pending admin review.
    """
    if db.query(models.User).filter(models.User.email == email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    id_url = await _save_upload(id_photo, "id_photos")
    face_url = await _save_upload(face_photo, "face_photos")

    user = models.User(
        name=name,
        email=email,
        password_hash=hash_password(password),
        id_photo_url=id_url,
        face_photo_url=face_url,
        verified=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=schemas.TokenResponse)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """Login with email + password, receive JWT access token."""
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=token)
