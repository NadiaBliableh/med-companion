from fastapi import APIRouter, Depends, Response

from app.auth.schemas import (
    LoginRequest,
    LoginResponse,
    SignupRequest,
    UserResponse,
)
from app.auth.service import login_user, logout_session, signup_user
from app.dependencies import get_current_session


router = APIRouter(prefix="/auth")


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest, response: Response):
    result = login_user(body)
    response.headers["Cache-Control"] = "no-store"
    return result


@router.get("/me", response_model=UserResponse)
def me(
    response: Response,
    session=Depends(get_current_session),
):
    response.headers["Cache-Control"] = "no-store"

    return {
        "id": session["id"],
        "full_name": session["full_name"],
        "email": session["email"],
        "role": session["role"],
    }


@router.post("/logout", status_code=204)
def logout(session=Depends(get_current_session)):
    logout_session(session["session_id"])

    return Response(
        status_code=204,
        headers={"Cache-Control": "no-store"},
    )


@router.post(
    "/signup",
    response_model=UserResponse,
    status_code=201,
    responses={
        409: {"description": "Email is already registered"},
    },
)
def signup(body: SignupRequest, response: Response):
    result = signup_user(body)
    response.headers["Cache-Control"] = "no-store"
    return result
