from fastapi import HTTPException

from app.database import get_connection


# ---------------------------------------------------------------------------
# قسم Learn: قائمة المواد المنشورة، ومخطط المادة (المواضيع ودروسها + حالة
# الطالب). كل القيم تُحسب لحظيًا، وكل الاستعلامات SELECT فقط (قراءة محضة):
# تنفيذ GET لا يُنشئ ولا يعدّل أي صف (لا lesson_progress تلقائيًا).
#
# العناوين تُعاد بالإنجليزية دائمًا (name_en / title_en)؛ لغة الواجهة مسؤولية
# الفرونت. النشر مُمثَّل على مستوى الدرس فقط (lessons.status).
#
# إتاحة المحتوى منفصلة عن تقدّم الطالب:
#   - درس "متاح للدراسة" = منشور وله بلوك محتوى واحد على الأقل (lesson_blocks).
#   - درس منشور بلا محتوى = "Coming soon": يُعرَض عنوانًا فقط، ولا يُحتسب ضمن
#     الدروس المتاحة ولا في نسبة التقدّم.
#
# student_id يأتي من الجلسة فقط ⇒ عزل تام. عدد الاستعلامات ثابت لكل نقطة
# (لا N+1).
# ---------------------------------------------------------------------------


def list_published_subjects():
    # استعلام واحد: ضمّ المواد بالمواضيع بالدروس المنشورة فقط، وتجميع.
    # INNER JOIN على الدروس المنشورة يُقصي المواد بلا محتوى منشور.
    # LEFT JOIN على lesson_blocks لتمييز الدروس الجاهزة (المتاحة) من غيرها.
    # subjects بلا display_order ⇒ الترتيب بالـid.
    with get_connection() as connection:
        rows = connection.execute(
            """
            SELECT
                s.id,
                s.name_en,
                s.description,
                count(DISTINCT t.id) AS topics_count,
                count(DISTINCT l.id) AS lessons_count,
                count(DISTINCT l.id) FILTER (
                    WHERE lb.lesson_id IS NOT NULL
                ) AS available_lessons_count
            FROM public.subjects AS s
            JOIN public.topics AS t ON t.subject_id = s.id
            JOIN public.lessons AS l
              ON l.topic_id = t.id AND l.status = 'published'
            LEFT JOIN public.lesson_blocks AS lb ON lb.lesson_id = l.id
            GROUP BY s.id, s.name_en, s.description
            ORDER BY s.id;
            """
        ).fetchall()

    return [
        {
            "id": row["id"],
            "title": row["name_en"],
            "description": row["description"],
            "thumbnail_url": None,
            "topics_count": row["topics_count"],
            "lessons_count": row["lessons_count"],
            "available_lessons_count": row["available_lessons_count"],
        }
        for row in rows
    ]


def get_subject_outline(subject_id, student_id):
    with get_connection() as connection:
        subject = connection.execute(
            """
            SELECT id, name_en, description
            FROM public.subjects
            WHERE id = %s;
            """,
            (subject_id,),
        ).fetchone()

        # استعلام واحد لكل المواضيع المنشورة ودروسها المنشورة + حالة الطالب
        # + توفّر المحتوى (is_available عبر EXISTS على lesson_blocks).
        rows = connection.execute(
            """
            SELECT
                t.id AS topic_id,
                t.name_en AS topic_title,
                t.description AS topic_description,
                t.display_order AS topic_order,
                l.id AS lesson_id,
                l.title_en AS lesson_title,
                l.summary,
                l.display_order AS lesson_order,
                lp.status AS progress_status,
                EXISTS (
                    SELECT 1 FROM public.lesson_blocks AS lb
                    WHERE lb.lesson_id = l.id
                ) AS is_available
            FROM public.topics AS t
            JOIN public.lessons AS l
              ON l.topic_id = t.id AND l.status = 'published'
            LEFT JOIN public.lesson_progress AS lp
              ON lp.lesson_id = l.id AND lp.student_id = %(sid)s
            WHERE t.subject_id = %(subject_id)s
            ORDER BY t.display_order, t.id, l.display_order, l.id;
            """,
            {"sid": student_id, "subject_id": subject_id},
        ).fetchall()

    # المادة غير موجودة، أو موجودة بلا أي درس منشور ⇒ تُعدّ "غير منشورة" ⇒ 404.
    if subject is None or not rows:
        raise HTTPException(
            status_code=404,
            detail="Published subject not found.",
        )

    topics = []
    current = None
    for row in rows:
        if current is None or current["id"] != row["topic_id"]:
            current = {
                "id": row["topic_id"],
                "title": row["topic_title"],
                "description": row["topic_description"],
                "display_order": row["topic_order"],
                "lessons_count": 0,
                "available_lessons_count": 0,
                "completed_lessons": 0,
                "progress_percentage": 0.0,
                "lessons": [],
            }
            topics.append(current)

        status = row["progress_status"] or "not_started"
        is_available = row["is_available"]
        current["lessons_count"] += 1
        if is_available:
            current["available_lessons_count"] += 1
            # المكتمل يُحتسب فقط إن كان الدرس متاحًا (منشور وله محتوى).
            if status == "completed":
                current["completed_lessons"] += 1
        current["lessons"].append(
            {
                "id": row["lesson_id"],
                "title": row["lesson_title"],
                "description": row["summary"],
                "display_order": row["lesson_order"],
                "status": status,
                "is_available": is_available,
                "thumbnail_url": None,
            }
        )

    for topic in topics:
        available = topic["available_lessons_count"]
        topic["progress_percentage"] = (
            round(topic["completed_lessons"] / available * 100, 2)
            if available > 0
            else 0.0
        )

    return {
        "id": subject["id"],
        "title": subject["name_en"],
        "description": subject["description"],
        "topics": topics,
    }
