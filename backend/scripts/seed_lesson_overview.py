"""إدخال قسم Overview لدرس Heart Chambers (محتوى إنجليزي، idempotent).

يبحث عن الدرس بمساره لا برقمه:
    Cardiovascular System → Heart Structure & Blood Flow → Heart Chambers
(رقم الدرس في قاعدة التطوير الحالية 13، لكنه غير مثبّت هنا.)

يخزّن القسم في lesson_blocks مع section='overview' وترتيب واضح:
    display_order=1  (title='Heart Chambers')          → introduction
    display_order=2  (title='Learning objectives')     → الأهداف، سطر لكلّ هدف

idempotent: إن وُجد قسم overview لهذا الدرس مسبقًا لا يُدرج شيء (لا تكرار، ولا
مسح لأي محتوى آخر). لا يضع روابط صور/فيديو وهمية. **لا يغيّر is_content_ready**:
الدرس يبقى "Coming soon" حتى يُضبط صراحةً.

يستهدف قاعدة الإعدادات (DB_NAME). لقاعدة التطوير:
    .\\.venv\\Scripts\\python.exe scripts\\seed_lesson_overview.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import get_connection  # noqa: E402


SUBJECT_EN = "Cardiovascular System"
TOPIC_EN = "Heart Structure & Blood Flow"
LESSON_EN = "Heart Chambers"
SECTION = "overview"

INTRODUCTION = (
    "Explore the four chambers of the heart and how they work together."
)
OBJECTIVES = [
    "Name the four chambers of the heart.",
    "Locate each chamber on a labelled diagram and a 3D model.",
    "Distinguish the roles of the atria and ventricles.",
]


def _find_lesson_id(connection):
    row = connection.execute(
        """
        SELECT l.id
        FROM public.lessons AS l
        JOIN public.topics AS t ON t.id = l.topic_id
        JOIN public.subjects AS s ON s.id = t.subject_id
        WHERE s.name_en = %s AND t.name_en = %s AND l.title_en = %s;
        """,
        (SUBJECT_EN, TOPIC_EN, LESSON_EN),
    ).fetchone()
    return row["id"] if row else None


def seed_overview():
    with get_connection() as connection:
        lesson_id = _find_lesson_id(connection)
        if lesson_id is None:
            raise SystemExit(
                f"Lesson not found: {SUBJECT_EN} > {TOPIC_EN} > {LESSON_EN}. "
                "Run scripts/seed_learn_content.py first."
            )

        existing = connection.execute(
            "SELECT count(*) AS n FROM public.lesson_blocks "
            "WHERE lesson_id = %s AND section = %s;",
            (lesson_id, SECTION),
        ).fetchone()["n"]
        if existing:
            print(f"overview already present for lesson_id={lesson_id} "
                  f"({existing} blocks); no change.")
            return

        connection.execute(
            """
            INSERT INTO public.lesson_blocks
                (lesson_id, section, block_type, title, text_content,
                 display_order)
            VALUES (%s, %s, 'text', %s, %s, 1);
            """,
            (lesson_id, SECTION, LESSON_EN, INTRODUCTION),
        )
        connection.execute(
            """
            INSERT INTO public.lesson_blocks
                (lesson_id, section, block_type, title, text_content,
                 display_order)
            VALUES (%s, %s, 'text', %s, %s, 2);
            """,
            (lesson_id, SECTION, "Learning objectives", "\n".join(OBJECTIVES)),
        )
        print(f"overview inserted for lesson_id={lesson_id} "
              f"(2 blocks, section='{SECTION}'); lesson stays Coming soon "
              f"(is_content_ready unchanged).")


if __name__ == "__main__":
    seed_overview()
