"""Seed محتوى Learn (المادة الأولى + موضوعها + 3 دروس منشورة).

idempotent: يمكن تشغيله أكثر من مرة دون تكرار الصفوف — يبحث عن كل صف
بمفتاحه الطبيعي (name_en / title_en داخل أبيه) قبل الإدراج.

يستهدف القاعدة المحدّدة في الإعدادات (DB_NAME). للتشغيل على قاعدة التطوير:
    .\\.venv\\Scripts\\python.exe scripts\\seed_learn_content.py
على قاعدة اختبار:
    $env:DB_NAME="med_companion_test"; .\\.venv\\Scripts\\python.exe scripts\\seed_learn_content.py

ملاحظات مخطط:
  - subjects/topics ليس لهما status ولا thumbnail_url؛ النشر على مستوى الدرس.
  - الوصف (description/summary) نص واحد؛ خزّنّا النص الإنجليزي كما ورد بالمواصفة.
  - الاسم/العنوان ثنائي اللغة (name_ar/name_en، title_ar/title_en): أضفنا
    ترجمة عربية معقولة لأن العمودين NOT NULL.

حالة الدروس المزروعة: تُدرَج status='published' لتظهر عناوينها، لكن
is_content_ready يبقى FALSE (الافتراضي) ⇒ تُعرَض كـ "Coming soon"
(is_available=false) ولا تُحتسب ضمن الدروس المتاحة للدراسة. الجاهزية قرار صريح
مستقلّ عن وجود المحتوى؛ إضافة بلوكات (مثل Overview) لا تجعل الدرس متاحًا.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import get_connection  # noqa: E402


SUBJECT = {
    "name_en": "Cardiovascular System",
    "name_ar": "الجهاز القلبي الوعائي",
    "description": "Explore heart anatomy and function.",
}

TOPIC = {
    "name_en": "Heart Structure & Blood Flow",
    "name_ar": "بنية القلب وتدفّق الدم",
    "description": "Chambers, valves and the pathway of blood.",
    "display_order": 1,
}

LESSONS = [
    {
        "title_en": "Heart Chambers",
        "title_ar": "حُجُرات القلب",
        "summary": (
            "Identify the four chambers and understand their basic roles."
        ),
        "display_order": 1,
    },
    {
        "title_en": "Heart Valves & Great Vessels",
        "title_ar": "صمّامات القلب والأوعية الكبرى",
        "summary": (
            "Explore heart valves and the major vessels connected to the "
            "heart."
        ),
        "display_order": 2,
    },
    {
        "title_en": "Blood Flow Through the Heart",
        "title_ar": "تدفّق الدم عبر القلب",
        "summary": "Trace the path of blood through the heart.",
        "display_order": 3,
    },
]


def _get_or_create_subject(connection):
    row = connection.execute(
        "SELECT id FROM public.subjects WHERE name_en = %s;",
        (SUBJECT["name_en"],),
    ).fetchone()
    if row is not None:
        return row["id"], False
    row = connection.execute(
        """
        INSERT INTO public.subjects (name_ar, name_en, description)
        VALUES (%s, %s, %s) RETURNING id;
        """,
        (SUBJECT["name_ar"], SUBJECT["name_en"], SUBJECT["description"]),
    ).fetchone()
    return row["id"], True


def _get_or_create_topic(connection, subject_id):
    row = connection.execute(
        "SELECT id FROM public.topics "
        "WHERE subject_id = %s AND name_en = %s;",
        (subject_id, TOPIC["name_en"]),
    ).fetchone()
    if row is not None:
        return row["id"], False
    row = connection.execute(
        """
        INSERT INTO public.topics
            (subject_id, name_ar, name_en, description, display_order)
        VALUES (%s, %s, %s, %s, %s) RETURNING id;
        """,
        (
            subject_id,
            TOPIC["name_ar"],
            TOPIC["name_en"],
            TOPIC["description"],
            TOPIC["display_order"],
        ),
    ).fetchone()
    return row["id"], True


def _get_or_create_lesson(connection, topic_id, lesson):
    row = connection.execute(
        "SELECT id FROM public.lessons "
        "WHERE topic_id = %s AND title_en = %s;",
        (topic_id, lesson["title_en"]),
    ).fetchone()
    if row is not None:
        return row["id"], False
    row = connection.execute(
        """
        INSERT INTO public.lessons
            (topic_id, title_ar, title_en, summary, display_order, status)
        VALUES (%s, %s, %s, %s, %s, 'published') RETURNING id;
        """,
        (
            topic_id,
            lesson["title_ar"],
            lesson["title_en"],
            lesson["summary"],
            lesson["display_order"],
        ),
    ).fetchone()
    return row["id"], True


def seed():
    created = {"subjects": 0, "topics": 0, "lessons": 0}
    # كل الإدراجات في معاملة واحدة (get_connection يثبّت عند الخروج السليم).
    with get_connection() as connection:
        subject_id, made = _get_or_create_subject(connection)
        created["subjects"] += int(made)

        topic_id, made = _get_or_create_topic(connection, subject_id)
        created["topics"] += int(made)

        for lesson in LESSONS:
            _, made = _get_or_create_lesson(connection, topic_id, lesson)
            created["lessons"] += int(made)

    print(
        f"seed done: subject_id={subject_id}, topic_id={topic_id}, "
        f"created={created}"
    )


if __name__ == "__main__":
    seed()
