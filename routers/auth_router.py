import os
import uuid
import aiofiles
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from database import get_db
from auth import hash_password, verify_password, create_access_token
import models
import schemas

UPLOAD_DIR = os.getenv("UPLOAD_DIR", "data/uploads")
MAX_VERIFICATION_FILE_BYTES = 10 * 1024 * 1024
VERIFICATION_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "application/pdf": ".pdf",
}

router = APIRouter(prefix="/auth", tags=["auth"])


async def _save_upload(file: UploadFile, subfolder: str) -> str:
    ext = VERIFICATION_EXTENSIONS.get(file.content_type or "")
    if not ext or (subfolder == "selfies" and file.content_type == "application/pdf"):
        raise HTTPException(status_code=415, detail="Unsupported verification file type")
    content = await file.read(MAX_VERIFICATION_FILE_BYTES + 1)
    if len(content) > MAX_VERIFICATION_FILE_BYTES:
        raise HTTPException(status_code=413, detail="Verification files must be 10 MB or smaller")
    dest = os.path.join(UPLOAD_DIR, subfolder)
    os.makedirs(dest, exist_ok=True)
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(dest, filename)
    async with aiofiles.open(filepath, "wb") as f:
        await f.write(content)
    return f"/uploads/{subfolder}/{filename}"


@router.post("/register", response_model=schemas.UserOut, status_code=status.HTTP_201_CREATED)
async def register(
    name: str = Form(...),
    email: str = Form(...),
    password: str = Form(..., min_length=8),
    id_document: UploadFile = File(..., description="Government-issued ID"),
    selfie: UploadFile = File(..., description="Selfie / face photo"),
    db: Session = Depends(get_db),
):
    """Register. Account is unverified until admin reviews ID + selfie."""
    if db.query(models.User).filter(models.User.email == email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    id_url = await _save_upload(id_document, "id_documents")
    selfie_url = await _save_upload(selfie, "selfies")

    user = models.User(
        name=name,
        email=email,
        password_hash=hash_password(password),
        id_document_url=id_url,
        selfie_url=selfie_url,
        verified=False,
    )
    db.add(user)
    db.flush()

    gamification = models.UserGamification(user_id=user.id)
    db.add(gamification)
    db.commit()
    db.refresh(user)
    return _user_out(user)


@router.post("/login", response_model=schemas.TokenResponse)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token({"sub": str(user.id)})
    return schemas.TokenResponse(access_token=token)


def _user_out(user: models.User) -> schemas.UserOut:
    return schemas.UserOut(
        id=user.id,
        name=user.name,
        email=user.email,
        id_document_url=user.id_document_url,
        selfie_url=user.selfie_url,
        verified=user.verified,
        role=user.role,
        rating=user.rating,
        points_balance=user.points_balance,
        created_at=user.created_at,
    )
