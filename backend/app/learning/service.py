from fastapi import HTTPException

from app.database import get_connection


# ---------------------------------------------------------------------------
# قسم Learn: قائمة المواد، مخطط المادة، وتفاصيل الدرس (أقسامه المرتبة).
# كل الاستعلامات SELECT فقط (قراءة محضة): تنفيذ GET لا يُنشئ ولا يعدّل أي صف
# (لا lesson_progress تلقائيًا).
#
# العناوين تُعاد بالإنجليزية دائمًا (name_en / title_en)؛ لغة الواجهة مسؤولية
# الفرونت. النشر مُمثَّل على مستوى الدرس (lessons.status).
#
# إتاحة المحتوى منفصلة عن تقدّم الطالب وعن مجرّد وجود بلوكات:
#   - درس "متاح للدراسة" = منشور و is_content_ready = TRUE (قرار صريح).
#     مجرّد وجود بلوك (مثل قسم Overview) لا يجعله متاحًا.
#   - درس منشور غير جاهز = "Coming soon": يُعرَض عنوانًا فقط، ولا يُحتسب ضمن
#     الدروس المتاحة ولا في نسبة التقدّم، ولا يُفتح محتواه للطالب.
#
# student_id يأتي من الجلسة فقط ⇒ عزل تام. عدد الاستعلامات ثابت لكل نقطة.
# ---------------------------------------------------------------------------


def list_published_subjects():
    # استعلام واحد: ضمّ المواد بالمواضيع بالدروس المنشورة فقط، وتجميع.
    # available_lessons_count يَعُدّ الدروس الجاهزة (is_content_ready) فقط.
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
                    WHERE l.is_content_ready
                ) AS available_lessons_count
            FROM public.subjects AS s
            JOIN public.topics AS t ON t.subject_id = s.id
            JOIN public.lessons AS l
              ON l.topic_id = t.id AND l.status = 'published'
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
        # + جاهزية المحتوى (is_available = is_content_ready).
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
                l.is_content_ready AS is_available,
                EXISTS (
                    SELECT 1 FROM public.lesson_blocks AS lb
                    WHERE lb.lesson_id = l.id
                ) AS can_open
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
            # المكتمل يُحتسب فقط إن كان الدرس متاحًا (جاهز المحتوى).
            if status == "completed":
                current["completed_lessons"] += 1
        current["lessons"].append(
            {
                "id": row["lesson_id"],
                "title": row["lesson_title"],
                "description": row["summary"],
                "display_order": row["lesson_order"],
                "status": status,
                "can_open": row["can_open"],
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


def get_lesson_detail(lesson_id, student_id):
    """تفاصيل درس وأقسامه المرتبة (قراءة فقط).

    يُعرَض محتوى الدرس المنشور **القابل للفتح** (له محتوى/بلوكات)، حتى لو لم
    يكتمل تجهيزه (is_content_ready=false) — دعمًا لعرض المحتوى تدريجيًا. أمّا:
      - الدرس غير المنشور ⇒ 404 (محجوب دائمًا).
      - الدرس المنشور بلا محتوى (غير قابل للفتح، "Coming soon") ⇒ 404.
    can_open في الاستجابة = منشور وله محتوى (true دائمًا هنا عند النجاح).
    is_available يبقى مرتبطًا بالجاهزية (is_content_ready) ولا يتأثّر بالفتح.
    """
    with get_connection() as connection:
        lesson = connection.execute(
            """
            SELECT
                l.id,
                l.title_en,
                l.summary,
                l.status,
                l.is_content_ready,
                lp.status AS progress_status,
                EXISTS (
                    SELECT 1 FROM public.lesson_blocks AS lb
                    WHERE lb.lesson_id = l.id
                ) AS has_content
            FROM public.lessons AS l
            LEFT JOIN public.lesson_progress AS lp
              ON lp.lesson_id = l.id AND lp.student_id = %(sid)s
            WHERE l.id = %(lid)s;
            """,
            {"sid": student_id, "lid": lesson_id},
        ).fetchone()

        if lesson is None or lesson["status"] != "published":
            raise HTTPException(status_code=404, detail="Lesson not found.")
        if not lesson["has_content"]:
            # منشور لكن بلا محتوى (غير قابل للفتح، "Coming soon") ⇒ لا شيء يُعرَض.
            raise HTTPException(status_code=404, detail="Lesson not found.")

        blocks = connection.execute(
            """
            SELECT
                COALESCE(section, 'general') AS section,
                display_order,
                block_type,
                title,
                text_content,
                resource_url,
                alternative_text
            FROM public.lesson_blocks
            WHERE lesson_id = %s
            ORDER BY display_order, id;
            """,
            (lesson_id,),
        ).fetchall()

    # تجميع البلوكات في أقسام مرتبة. ترتيب القسم = أصغر display_order فيه
    # (أول ظهور لأن الصفوف مرتبة تصاعديًا).
    sections = []
    index = {}
    for block in blocks:
        key = block["section"]
        if key not in index:
            index[key] = {
                "key": key,
                "display_order": block["display_order"],
                "blocks": [],
            }
            sections.append(index[key])
        index[key]["blocks"].append(
            {
                "display_order": block["display_order"],
                "block_type": block["block_type"],
                "title": block["title"],
                "text": block["text_content"],
                "resource_url": block["resource_url"],
                "alternative_text": block["alternative_text"],
            }
        )

    return {
        "id": lesson["id"],
        "title": lesson["title_en"],
        "description": lesson["summary"],
        "can_open": True,  # نجَح الفتح ⇒ منشور وله محتوى.
        "is_available": lesson["is_content_ready"],
        "status": lesson["progress_status"] or "not_started",
        "sections": sections,
    }
