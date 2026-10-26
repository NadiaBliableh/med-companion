from fastapi import HTTPException

import psycopg

from app.auth.schemas import LoginRequest, SignupRequest
from app.database import get_connection
from app.security import (
    generate_session_token,
    hash_password,
    hash_session_token,
    verify_password,
)


# مدة الجلسة في النسخة التجريبية
SESSION_HOURS = 8

# لإجراء تحقق بكلمة المرور حتى عندما يكون البريد غير موجود
DUMMY_PASSWORD_HASH = hash_password(generate_session_token())


def login_user(body: LoginRequest):
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


def signup_user(body: SignupRequest):
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

    return {
        "id": user["id"],
        "full_name": user["full_name"],
        "email": user["email"],
        "role": user["role"],
    }


def logout_session(session_id):
    with get_connection() as connection:
        connection.execute(
            """
            UPDATE public.auth_sessions
            SET revoked_at = CURRENT_TIMESTAMP
            WHERE id = %s
              AND revoked_at IS NULL;
            """,
            (session_id,),
        )
