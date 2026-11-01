"""إدخال قسم Core Anatomy لدرس Heart Chambers (محتوى إنجليزي، idempotent).

يبحث عن الدرس بمساره لا برقمه:
    Cardiovascular System → Heart Structure & Blood Flow → Heart Chambers

يخزّن في lesson_blocks (block_type='text', section='core_anatomy') بلوكات
منظّمة بمفاتيح ثابتة (block_key) وحمولة JSONB (data):
    core_intro        (content_type='intro')        display_order 3
    core_right_atrium (content_type='chamber')      4
    core_right_ventricle                            5
    core_left_atrium                                6
    core_left_ventricle                             7
    core_comparison   (content_type='comparison')   8
    core_recall       (content_type='think_reveal') 9
    core_glossary     (content_type='glossary')     10  (يُرفَع لمستوى الدرس)

- segments تربط كلمات النص بمعرّفات المصطلحات؛ تجميعها = النص الكامل.
- المصادر تُخزَّن في source_documents + lesson_sources (idempotent بالرابط).
- لا يغيّر is_content_ready (يبقى الدرس غير جاهز)، ولا يمسّ Overview.
- idempotent: إن وُجد القسم لا يُعاد إدخاله. **للتحديث** شغّل مع FORCE=1
  فيُحذف قسم core_anatomy ويُعاد إدخاله (لا يمسّ أقسامًا أخرى):
      $env:FORCE="1"; .\\.venv\\Scripts\\python.exe scripts\\seed_lesson_core_anatomy.py

يستهدف قاعدة الإعدادات (DB_NAME).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from psycopg.types.json import Jsonb  # noqa: E402

from app.database import get_connection  # noqa: E402

SUBJECT_EN = "Cardiovascular System"
TOPIC_EN = "Heart Structure & Blood Flow"
LESSON_EN = "Heart Chambers"
SECTION = "core_anatomy"

INTRO_TEXT = (
    "The heart has two atria and two ventricles. The atria receive blood "
    "returning to the heart; the ventricles pump blood out. The right side "
    "sends blood to the lungs, while the left side supplies the systemic "
    "circulation."
)

RIGHT_ATRIUM_TEXT = (
    "The right atrium receives oxygen-poor blood through the superior and "
    "inferior venae cavae. It also receives blood returning from the heart "
    "muscle through the coronary sinus. Blood passes from the right atrium "
    "through the tricuspid valve into the right ventricle."
)
RIGHT_VENTRICLE_TEXT = (
    "The right ventricle receives blood from the right atrium. It pumps "
    "blood through the pulmonary valve into the pulmonary trunk, which "
    "divides into the pulmonary arteries leading to the lungs."
)
LEFT_ATRIUM_TEXT = (
    "The left atrium receives oxygen-rich blood returning from the lungs "
    "through the pulmonary veins. Blood then passes through the mitral valve "
    "into the left ventricle."
)
LEFT_VENTRICLE_TEXT = (
    "The left ventricle receives blood from the left atrium and pumps it "
    "through the aortic valve into the aorta. Its muscular wall is thicker "
    "than the right ventricle's because it generates the higher pressure "
    "needed for systemic circulation."
)

CHAMBERS = [
    {
        "block_key": "core_right_atrium",
        "structure_key": "right_atrium",
        "title": "Right Atrium",
        "abbreviation": "RA",
        "text": RIGHT_ATRIUM_TEXT,
        "links": [("venae cavae", "vena_cava"),
                  ("coronary sinus", "coronary_sinus")],
        "key_point": ("The right atrium receives returning blood; it does "
                      "not pump directly to the lungs."),
    },
    {
        "block_key": "core_right_ventricle",
        "structure_key": "right_ventricle",
        "title": "Right Ventricle",
        "abbreviation": "RV",
        "text": RIGHT_VENTRICLE_TEXT,
        "links": [],
        "key_point": "The right ventricle supplies the pulmonary circulation.",
    },
    {
        "block_key": "core_left_atrium",
        "structure_key": "left_atrium",
        "title": "Left Atrium",
        "abbreviation": "LA",
        "text": LEFT_ATRIUM_TEXT,
        "links": [("pulmonary veins", "pulmonary_veins")],
        "key_point": ("Pulmonary veins carry oxygen-rich blood toward the "
                      "heart."),
    },
    {
        "block_key": "core_left_ventricle",
        "structure_key": "left_ventricle",
        "title": "Left Ventricle",
        "abbreviation": "LV",
        "text": LEFT_VENTRICLE_TEXT,
        "links": [("aorta", "aorta"),
                  ("systemic circulation", "systemic_circulation")],
        "key_point": "The left ventricle supplies the systemic circulation.",
    },
]

INTRO_LINKS = [("atria", "atrium"), ("ventricles", "ventricle"),
               ("systemic circulation", "systemic_circulation")]

COMPARISON = {
    "columns": ["Chamber", "Receives blood from", "Sends blood to"],
    "rows": [
        ["Right atrium", "Venae cavae and coronary sinus", "Right ventricle"],
        ["Right ventricle", "Right atrium", "Pulmonary trunk → lungs"],
        ["Left atrium", "Pulmonary veins", "Left ventricle"],
        ["Left ventricle", "Left atrium", "Aorta → systemic circulation"],
    ],
}

RECALL = {
    "prompt": ("Why is the wall of the left ventricle thicker than that of "
               "the right ventricle?"),
    "explanation": ("The left ventricle generates higher pressure to drive "
                    "blood through systemic circulation. The right ventricle "
                    "pumps through the lower-pressure pulmonary circulation."),
}

TERMS = [
    {"id": "atrium", "plural": "atria",
     "definition": "A heart chamber that receives returning blood."},
    {"id": "ventricle",
     "definition": "A heart chamber that pumps blood into an artery."},
    {"id": "pulmonary_circulation",
     "definition": ("Blood flow from the right ventricle through the lungs "
                    "and back to the left atrium.")},
    {"id": "systemic_circulation",
     "definition": ("Blood flow from the left ventricle through the body's "
                    "tissues and back to the right atrium.")},
    {"id": "vena_cava", "plural": "venae cavae",
     "definition": ("One of the two large veins returning systemic venous "
                    "blood to the right atrium.")},
    {"id": "coronary_sinus",
     "definition": ("A venous channel that collects much of the blood "
                    "returning from the heart muscle and drains into the "
                    "right atrium.")},
    {"id": "pulmonary_veins",
     "definition": ("Veins that return oxygen-rich blood from the lungs to "
                    "the left atrium.")},
    {"id": "aorta",
     "definition": ("The main artery carrying blood from the left ventricle "
                    "into the systemic circulation.")},
]

SOURCES = [
    ("NIH / NHLBI — What the Heart Looks Like",
     "https://www.nhlbi.nih.gov/health/heart/anatomy"),
    ("NCI / SEER — Structure of the Heart",
     "https://www.training.seer.cancer.gov/anatomy/cardiovascular/heart/"
     "structure.html"),
    ("StatPearls — Anatomy, Thorax, Heart",
     "https://www.ncbi.nlm.nih.gov/books/NBK470256/"),
]


def _segments(text, links):
    """يقسّم النص إلى أجزاء؛ أجزاء العبارات المرتبطة تحمل term_id.

    links: قائمة (عبارة، term_id) بترتيب ظهورها وغير متداخلة. يضمن أن
    "".join(part["text"]) == text تمامًا.
    """
    segments = []
    i = 0
    for phrase, term_id in links:
        j = text.index(phrase, i)
        if j > i:
            segments.append({"text": text[i:j]})
        segments.append({"text": phrase, "term_id": term_id})
        i = j + len(phrase)
    if i < len(text):
        segments.append({"text": text[i:]})
    return segments


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


def _insert_block(connection, lesson_id, order, block_key, content_type,
                  title, text, data):
    connection.execute(
        """
        INSERT INTO public.lesson_blocks
            (lesson_id, section, block_type, content_type, block_key,
             title, text_content, data, display_order)
        VALUES (%s, %s, 'text', %s, %s, %s, %s, %s, %s);
        """,
        (lesson_id, SECTION, content_type, block_key, title, text,
         Jsonb(data), order),
    )


def _ensure_source(connection, lesson_id, title, url):
    row = connection.execute(
        "SELECT id FROM public.source_documents WHERE source_url = %s;",
        (url,),
    ).fetchone()
    if row is None:
        row = connection.execute(
            "INSERT INTO public.source_documents (title, source_type, "
            "source_url) VALUES (%s, 'website', %s) RETURNING id;",
            (title, url),
        ).fetchone()
    source_id = row["id"]
    connection.execute(
        "INSERT INTO public.lesson_sources (lesson_id, source_document_id) "
        "VALUES (%s, %s) ON CONFLICT (lesson_id, source_document_id) "
        "DO NOTHING;",
        (lesson_id, source_id),
    )


def seed_core_anatomy():
    force = os.environ.get("FORCE") == "1"
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
        if existing and not force:
            print(f"core_anatomy already present for lesson_id={lesson_id} "
                  f"({existing} blocks); no change. "
                  "Run with FORCE=1 to replace this section only.")
            # المصادر idempotent على أي حال.
            for title, url in SOURCES:
                _ensure_source(connection, lesson_id, title, url)
            return
        if existing and force:
            connection.execute(
                "DELETE FROM public.lesson_blocks WHERE lesson_id = %s "
                "AND section = %s;",
                (lesson_id, SECTION),
            )
            print(f"FORCE: removed {existing} existing core_anatomy blocks.")

        # 3) مقدّمة
        _insert_block(
            connection, lesson_id, 3, "core_intro", "intro",
            "Four chambers, two sides", INTRO_TEXT,
            {"segments": _segments(INTRO_TEXT, INTRO_LINKS)},
        )
        # 4..7) بطاقات الحجرات الأربع
        order = 4
        for ch in CHAMBERS:
            _insert_block(
                connection, lesson_id, order, ch["block_key"], "chamber",
                ch["title"], ch["text"],
                {
                    "structure_key": ch["structure_key"],
                    "abbreviation": ch["abbreviation"],
                    "key_point": ch["key_point"],
                    "segments": _segments(ch["text"], ch["links"]),
                },
            )
            order += 1
        # 8) المقارنة
        _insert_block(
            connection, lesson_id, 8, "core_comparison", "comparison",
            "Chamber comparison",
            "Comparison of the four heart chambers.",
            {"comparison": COMPARISON},
        )
        # 9) سؤال التذكّر (Think → Reveal)
        _insert_block(
            connection, lesson_id, 9, "core_recall", "think_reveal",
            "Recall", RECALL["prompt"],
            {"think_reveal": RECALL},
        )
        # 10) المسرد (يُرفَع لمستوى الدرس في الاستجابة)
        _insert_block(
            connection, lesson_id, 10, "core_glossary", "glossary",
            "Glossary", "Key terms for this lesson.",
            {"terms": TERMS},
        )
        # المصادر
        for title, url in SOURCES:
            _ensure_source(connection, lesson_id, title, url)

        print(f"core_anatomy inserted for lesson_id={lesson_id} "
              f"(8 blocks + {len(SOURCES)} sources); is_content_ready "
              "unchanged (lesson stays not available).")


if __name__ == "__main__":
    seed_core_anatomy()
