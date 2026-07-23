from fastapi import APIRouter
from pydantic import BaseModel

from app.services.auth_service import AuthService

router = APIRouter()


class SignUpRequest(BaseModel):
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


@router.post("/signup")
def signup(data: SignUpRequest):
    return AuthService.sign_up(
        data.email,
        data.password
    )


@router.post("/login")
def login(data: LoginRequest):
    return AuthService.sign_in(
        data.email,
        data.password
    )
