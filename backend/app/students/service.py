from fastapi import HTTPException
from psycopg import sql

from app.database import get_connection


# الأعمدة المسموح تحديثها في student_profiles، كقائمة ثابتة.
# لا تُبنى أسماء الأعمدة من مفاتيح الطلب مباشرة.
PROFILE_COLUMNS = ("university", "study_year", "preferred_language")


def _fetch_profile(connection, user_id):
    return connection.execute(
        """
        SELECT
            u.id,
            u.full_name,
            u.email,
            sp.university,
            sp.study_year,
            sp.preferred_language
        FROM public.users AS u
        JOIN public.student_profiles AS sp ON sp.user_id = u.id
        WHERE u.id = %s;
        """,
        (user_id,),
    ).fetchone()


def get_student_profile(user_id):
    with get_connection() as connection:
        profile = _fetch_profile(connection, user_id)

    if profile is None:
        raise HTTPException(
            status_code=404,
            detail="Student profile not found.",
        )

    return profile


def update_student_profile(user_id, changes):
    # التحديثان داخل معاملة واحدة: يُثبَّتان معًا، ويتراجعان معًا عند الفشل.
    with get_connection() as connection:
        exists = connection.execute(
            "SELECT 1 FROM public.student_profiles WHERE user_id = %s;",
            (user_id,),
        ).fetchone()

        if exists is None:
            # رفع الاستثناء هنا يُنهي المعاملة بالتراجع دون أي تعديل.
            raise HTTPException(
                status_code=404,
                detail="Student profile not found.",
            )

        if "full_name" in changes:
            connection.execute(
                "UPDATE public.users SET full_name = %s WHERE id = %s;",
                (changes["full_name"], user_id),
            )

        profile_updates = [
            (column, changes[column])
            for column in PROFILE_COLUMNS
            if column in changes
        ]

        if profile_updates:
            assignments = sql.SQL(", ").join(
                sql.SQL("{} = %s").format(sql.Identifier(column))
                for column, _ in profile_updates
            )
            query = sql.SQL(
                "UPDATE public.student_profiles SET {} WHERE user_id = %s;"
            ).format(assignments)
            params = [value for _, value in profile_updates]
            params.append(user_id)
            connection.execute(query, params)

        profile = _fetch_profile(connection, user_id)

    return profile
