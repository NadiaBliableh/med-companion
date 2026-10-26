from datetime import datetime

import psycopg
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field
from typing import Literal
from pydantic import ConfigDict, field_validator

from database import get_connection
from security import (
    generate_session_token,
    hash_password,
    hash_session_token,
    verify_password,
)


app = FastAPI(
    title="Med Companion API",
    version="0.1.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

bearer_scheme = HTTPBearer(auto_error=False)

# مدة الجلسة في النسخة التجريبية
SESSION_HOURS = 8

# لإجراء تحقق بكلمة المرور حتى عندما يكون البريد غير موجود
DUMMY_PASSWORD_HASH = hash_password(generate_session_token())


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserResponse


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request, exc):
    # لا نعيد قيم المدخلات، خصوصًا كلمة المرور، داخل رسائل الخطأ
    errors = [
        {
            "loc": error["loc"],
            "msg": error["msg"],
            "type": error["type"],
        }
        for error in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": errors})


@app.exception_handler(psycopg.Error)
async def database_error_handler(request, exc):
    return JSONResponse(
        status_code=503,
        content={"detail": "Database service is temporarily unavailable."},
    )


def unauthorized():
    return HTTPException(
        status_code=401,
        detail="Invalid or expired session. Please log in.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_session(
    credentials: HTTPAuthorizationCredentials | None = Depends(
        bearer_scheme
    ),
):
    if credentials is None:
        raise unauthorized()

    token = credentials.credentials

    if not 20 <= len(token) <= 200:
        raise unauthorized()

    token_hash = hash_session_token(token)

    with get_connection() as connection:
        session = connection.execute(
            """
            SELECT
                s.id AS session_id,
                u.id,
                u.full_name,
                u.email,
                u.role
            FROM public.auth_sessions AS s
            JOIN public.users AS u ON u.id = s.user_id
            WHERE s.token_hash = %s
              AND s.revoked_at IS NULL
              AND s.expires_at > CURRENT_TIMESTAMP
              AND u.is_active = TRUE;
            """,
            (token_hash,),
        ).fetchone()

    if session is None:
        raise unauthorized()

    return session

class SignupRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(min_length=1, max_length=150)
    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=15, max_length=128)
    university: str | None = Field(default=None, max_length=200)
    study_year: int | None = Field(default=None, ge=1, le=6)
    preferred_language: Literal["ar", "en"] = "ar"

    @field_validator("full_name", mode="before")
    @classmethod
    def clean_full_name(cls, value):
        if isinstance(value, str):
            return value.strip()
        return value

    @field_validator("university", mode="before")
    @classmethod
    def clean_university(cls, value):
        if isinstance(value, str):
            return value.strip() or None
        return value
    
@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/auth/login", response_model=LoginResponse)
def login(body: LoginRequest, response: Response):
    email = str(body.email).strip().lower()

    with get_connection() as connection:
        user = connection.execute(
            """
            SELECT
                id,
                full_name,
                email,
                password_hash,
                role,
                is_active
            FROM public.users
            WHERE LOWER(TRIM(email)) = %s;
            """,
            (email,),
        ).fetchone()

    stored_hash = (
        user["password_hash"]
        if user is not None
        else DUMMY_PASSWORD_HASH
    )

    password_valid = verify_password(body.password, stored_hash)

    if user is None or not password_valid or not user["is_active"]:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = generate_session_token()
    token_hash = hash_session_token(token)

    with get_connection() as connection:
        session = connection.execute(
            """
            INSERT INTO public.auth_sessions (
                user_id,
                token_hash,
                expires_at
            )
            VALUES (
                %s,
                %s,
                CURRENT_TIMESTAMP + (%s * INTERVAL '1 hour')
            )
            RETURNING expires_at;
            """,
            (user["id"], token_hash, SESSION_HOURS),
        ).fetchone()

    response.headers["Cache-Control"] = "no-store"

    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_at": session["expires_at"],
        "user": {
            "id": user["id"],
            "full_name": user["full_name"],
            "email": user["email"],
            "role": user["role"],
        },
    }


@app.get("/auth/me", response_model=UserResponse)
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


@app.post("/auth/logout", status_code=204)
def logout(session=Depends(get_current_session)):
    with get_connection() as connection:
        connection.execute(
            """
            UPDATE public.auth_sessions
            SET revoked_at = CURRENT_TIMESTAMP
            WHERE id = %s
              AND revoked_at IS NULL;
            """,
            (session["session_id"],),
        )

    return Response(
        status_code=204,
        headers={"Cache-Control": "no-store"},
    )
@app.post(
    "/auth/signup",
    response_model=UserResponse,
    status_code=201,
    responses={
        409: {"description": "Email is already registered"},
    },
)
def signup(body: SignupRequest, response: Response):
    email = str(body.email).strip().lower()

    # نحسب الـHash قبل فتح اتصال قاعدة البيانات.
    password_hash = hash_password(body.password)

    try:
        with get_connection() as connection:
            user = connection.execute(
                """
                INSERT INTO public.users (
                    full_name,
                    email,
                    password_hash,
                    role
                )
                VALUES (%s, %s, %s, 'student')
                RETURNING id, full_name, email, role;
                """,
                (
                    body.full_name,
                    email,
                    password_hash,
                ),
            ).fetchone()

            connection.execute(
                """
                INSERT INTO public.student_profiles (
                    user_id,
                    university,
                    study_year,
                    preferred_language
                )
                VALUES (%s, %s, %s, %s);
                """,
                (
                    user["id"],
                    body.university,
                    body.study_year,
                    body.preferred_language,
                ),
            )

    except psycopg.errors.UniqueViolation as exc:
        # هذا اسم فهرس الإيميل الذي أنشأناه سابقًا.
        if exc.diag.constraint_name == "users_email_unique":
            raise HTTPException(
                status_code=409,
                detail="Email is already registered.",
            ) from None

        # أي تعارض آخر يعالجه معالج أخطاء قاعدة البيانات.
        raise

    response.headers["Cache-Control"] = "no-store"

    return {
        "id": user["id"],
        "full_name": user["full_name"],
        "email": user["email"],
        "role": user["role"],
    }
