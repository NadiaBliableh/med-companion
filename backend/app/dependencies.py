from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.database import get_connection
from app.security import hash_session_token


bearer_scheme = HTTPBearer(auto_error=False)


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
