from datetime import timedelta

from fastapi import HTTPException
from psycopg import sql

from app.database import get_connection


# نحدّد اليوم حسب توقيت فلسطين لحساب الـstreak والنشاط الأسبوعي.
LOCAL_TZ = "Asia/Hebron"

# حدّ اعتبار اليوم "يوم دراسة" في الـstreak: جلسة دراسة مكتملة >= 5 دقائق.
STREAK_MIN_STUDY_SECONDS = 300


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


# ---------------------------------------------------------------------------
# GET /students/me/profile-overview
#
# يحسب كل القيم لحظيًا من الجداول (لا تخزين في student_profiles).
# عدد الاستعلامات ثابت ولا يعتمد على حجم البيانات (لا N+1):
#   1) الملف  2) إحصائيات مجمّعة + اليوم المحلي  3) أيام الـstreak
#   4) النشاط الأسبوعي  5) اختيار درس المتابعة  6) إثراء بيانات الدرس.
# student_id يأتي من الجلسة فقط، وكل استعلام مقيَّد به ⇒ عزل تام بين الطلاب.
# ---------------------------------------------------------------------------


def _title_for_language(ar_value, en_value, language):
    return ar_value if language == "ar" else en_value


def _compute_streak(study_days, today):
    # study_days: مجموعة تواريخ محلية اعتُبرت "أيام دراسة".
    # اليوم لا يكسر الـstreak إن لم يُدرَس بعد (نبدأ من أمس عندها).
    if today in study_days:
        cursor = today
    elif (today - timedelta(days=1)) in study_days:
        cursor = today - timedelta(days=1)
    else:
        return 0

    streak = 0
    while cursor in study_days:
        streak += 1
        cursor -= timedelta(days=1)
    return streak


def _select_continue_lesson_id(connection, student_id):
    # (أ) آخر درس بدأه ولم يُكمله (الأحدث حسب last_accessed_at).
    row = connection.execute(
        """
        SELECT lp.lesson_id
        FROM public.lesson_progress AS lp
        JOIN public.lessons AS l
          ON l.id = lp.lesson_id AND l.status = 'published'
        WHERE lp.student_id = %s
          AND lp.status = 'in_progress'
        ORDER BY lp.last_accessed_at DESC, lp.lesson_id DESC
        LIMIT 1;
        """,
        (student_id,),
    ).fetchone()
    if row is not None:
        return row["lesson_id"]

    # (ب) أول درس منشور لم يُكمله الطالب، بترتيب موضوعي ثابت.
    row = connection.execute(
        """
        SELECT l.id
        FROM public.lessons AS l
        JOIN public.topics AS t ON t.id = l.topic_id
        JOIN public.subjects AS s ON s.id = t.subject_id
        WHERE l.status = 'published'
          AND NOT EXISTS (
              SELECT 1 FROM public.lesson_progress AS lp
              WHERE lp.student_id = %s
                AND lp.lesson_id = l.id
                AND lp.status = 'completed'
          )
        ORDER BY s.id, t.display_order, l.display_order, l.id
        LIMIT 1;
        """,
        (student_id,),
    ).fetchone()
    # (ج) لا شيء ⇒ أكمل كل الدروس (أو لا دروس منشورة) ⇒ None.
    return row["id"] if row is not None else None


def _build_continue_learning(connection, student_id, language):
    lesson_id = _select_continue_lesson_id(connection, student_id)
    if lesson_id is None:
        return None

    row = connection.execute(
        """
        WITH ranked AS (
            SELECT
                l.id AS lesson_id,
                ROW_NUMBER() OVER (
                    PARTITION BY l.topic_id
                    ORDER BY l.display_order, l.id
                ) AS lesson_order,
                COUNT(*) OVER (PARTITION BY l.topic_id) AS lessons_count
            FROM public.lessons AS l
            WHERE l.status = 'published'
        )
        SELECT
            s.id AS subject_id, s.name_ar AS subject_ar, s.name_en AS subject_en,
            t.id AS topic_id,   t.name_ar AS topic_ar,   t.name_en AS topic_en,
            l.id AS lesson_id,  l.title_ar AS lesson_ar, l.title_en AS lesson_en,
            r.lesson_order, r.lessons_count,
            lp.status AS lesson_status,
            (
                SELECT count(*)
                FROM public.lesson_progress AS lp2
                JOIN public.lessons AS l2 ON l2.id = lp2.lesson_id
                WHERE lp2.student_id = %(sid)s
                  AND lp2.status = 'completed'
                  AND l2.status = 'published'
                  AND l2.topic_id = l.topic_id
            ) AS completed_in_topic
        FROM ranked AS r
        JOIN public.lessons AS l ON l.id = r.lesson_id
        JOIN public.topics AS t ON t.id = l.topic_id
        JOIN public.subjects AS s ON s.id = t.subject_id
        LEFT JOIN public.lesson_progress AS lp
          ON lp.lesson_id = l.id AND lp.student_id = %(sid)s
        WHERE r.lesson_id = %(lid)s;
        """,
        {"sid": student_id, "lid": lesson_id},
    ).fetchone()

    lessons_count = row["lessons_count"]
    completed_in_topic = row["completed_in_topic"]
    topic_progress = (
        round(completed_in_topic / lessons_count * 100, 2)
        if lessons_count > 0
        else 0.0
    )

    return {
        "subject_id": row["subject_id"],
        "subject_title": _title_for_language(
            row["subject_ar"], row["subject_en"], language
        ),
        "topic_id": row["topic_id"],
        "topic_title": _title_for_language(
            row["topic_ar"], row["topic_en"], language
        ),
        "lesson_id": row["lesson_id"],
        "lesson_title": _title_for_language(
            row["lesson_ar"], row["lesson_en"], language
        ),
        "lesson_order": row["lesson_order"],
        "lessons_count": lessons_count,
        "status": (
            "in_progress"
            if row["lesson_status"] == "in_progress"
            else "not_started"
        ),
        "completed_lessons_in_topic": completed_in_topic,
        "topic_progress_percentage": topic_progress,
        "thumbnail_url": None,
    }


def get_profile_overview(user_id):
    with get_connection() as connection:
        # 1) الملف + اللغة المفضّلة (تحدّد لغة العناوين).
        profile = connection.execute(
            """
            SELECT
                u.full_name,
                sp.study_year,
                sp.preferred_language
            FROM public.users AS u
            JOIN public.student_profiles AS sp ON sp.user_id = u.id
            WHERE u.id = %s;
            """,
            (user_id,),
        ).fetchone()

        if profile is None:
            raise HTTPException(
                status_code=404,
                detail="Student profile not found.",
            )

        language = profile["preferred_language"]

        # 2) إحصائيات مجمّعة + اليوم المحلي في استعلام واحد.
        stats = connection.execute(
            """
            SELECT
                (CURRENT_TIMESTAMP AT TIME ZONE %(tz)s)::date AS today,
                COALESCE((
                    SELECT SUM(fs.accumulated_active_seconds)
                    FROM public.focus_sessions AS fs
                    WHERE fs.student_id = %(sid)s
                      AND fs.status = 'completed'
                      AND fs.phase = 'study'
                ), 0) AS total_study_seconds,
                (
                    SELECT count(*)
                    FROM public.lesson_progress AS lp
                    JOIN public.lessons AS l ON l.id = lp.lesson_id
                    WHERE lp.student_id = %(sid)s
                      AND lp.status = 'completed'
                      AND l.status = 'published'
                ) AS completed_lessons,
                (
                    SELECT count(*)
                    FROM public.lessons
                    WHERE status = 'published'
                ) AS published_lessons,
                (
                    SELECT count(*)
                    FROM public.saved_lessons AS sl
                    WHERE sl.student_id = %(sid)s
                ) AS saved_lessons_count;
            """,
            {"tz": LOCAL_TZ, "sid": user_id},
        ).fetchone()

        published = stats["published_lessons"]
        overall = (
            round(stats["completed_lessons"] / published * 100, 2)
            if published > 0
            else 0.0
        )

        # 3) أيام الدراسة المؤهِّلة للـstreak (تواريخ محلية مميّزة).
        day_rows = connection.execute(
            """
            SELECT DISTINCT day FROM (
                SELECT (fs.started_at AT TIME ZONE %(tz)s)::date AS day
                FROM public.focus_sessions AS fs
                WHERE fs.student_id = %(sid)s
                  AND fs.status = 'completed'
                  AND fs.phase = 'study'
                  AND fs.accumulated_active_seconds >= %(min_sec)s
                UNION
                SELECT (lp.completed_at AT TIME ZONE %(tz)s)::date AS day
                FROM public.lesson_progress AS lp
                WHERE lp.student_id = %(sid)s
                  AND lp.status = 'completed'
                  AND lp.completed_at IS NOT NULL
            ) AS q;
            """,
            {
                "tz": LOCAL_TZ,
                "sid": user_id,
                "min_sec": STREAK_MIN_STUDY_SECONDS,
            },
        ).fetchall()
        study_days = {r["day"] for r in day_rows}
        streak = _compute_streak(study_days, stats["today"])

        # 4) النشاط الأسبوعي: آخر 7 أيام محلية، بأصفار للأيام بلا نشاط.
        weekly = connection.execute(
            """
            WITH days AS (
                SELECT d::date AS day
                FROM generate_series(
                    (CURRENT_TIMESTAMP AT TIME ZONE %(tz)s)::date
                        - INTERVAL '6 day',
                    (CURRENT_TIMESTAMP AT TIME ZONE %(tz)s)::date,
                    INTERVAL '1 day'
                ) AS d
            ),
            sess AS (
                SELECT
                    (fs.started_at AT TIME ZONE %(tz)s)::date AS day,
                    SUM(fs.accumulated_active_seconds) AS secs
                FROM public.focus_sessions AS fs
                WHERE fs.student_id = %(sid)s
                  AND fs.status = 'completed'
                  AND fs.phase = 'study'
                  AND (fs.started_at AT TIME ZONE %(tz)s)::date
                      >= (CURRENT_TIMESTAMP AT TIME ZONE %(tz)s)::date
                          - INTERVAL '6 day'
                GROUP BY 1
            )
            SELECT days.day AS date,
                   COALESCE(sess.secs, 0)::bigint AS study_seconds
            FROM days
            LEFT JOIN sess ON sess.day = days.day
            ORDER BY days.day;
            """,
            {"tz": LOCAL_TZ, "sid": user_id},
        ).fetchall()

        # 5) + 6) درس المتابعة (قد يكون None).
        continue_learning = _build_continue_learning(
            connection, user_id, language
        )

    return {
        "profile": {
            "full_name": profile["full_name"],
            "avatar_url": None,
            "study_year": profile["study_year"],
            "preferred_language": language,
        },
        "stats": {
            "current_streak_days": streak,
            "total_study_seconds": int(stats["total_study_seconds"]),
            "overall_progress_percentage": overall,
        },
        "continue_learning": continue_learning,
        "weekly_activity": [
            {"date": r["date"], "study_seconds": int(r["study_seconds"])}
            for r in weekly
        ],
        "saved_lessons_count": stats["saved_lessons_count"],
    }
