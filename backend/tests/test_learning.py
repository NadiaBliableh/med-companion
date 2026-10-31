"""اختبارات قسم Learn: GET /learning/subjects و /learning/subjects/{id}/outline.

تعمل على **قاعدة اختبار منفصلة** فقط (لا تلمس القاعدة الفعلية إطلاقًا):
اسمها من المتغيّر البيئي MED_TEST_DB، وافتراضيًا "med_companion_test".
إن تعذّر الاتصال بها تُتخطّى الاختبارات (دون أي كتابة على القاعدة الحقيقية).

كل اختبار يزرع بياناته داخل معاملة واحدة لا تُحفظ (rollback في النهاية)،
ويوجّه اتصال الـservice إلى نفس المعاملة ليرى البيانات المزروعة.

تهيئة قاعدة الاختبار لمرة واحدة (CREATE DATABASE ثم تحميل المخطط):
    sql/000_med_companion_full_schema.sql

التشغيل (pytest غير مثبّت):
    .\\.venv\\Scripts\\python.exe tests\\test_learning.py
مع pytest إن ثُبِّت:
    .\\.venv\\Scripts\\python.exe -m pytest tests/test_learning.py -v
"""

import os
import sys
from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.learning import service  # noqa: E402
from app.students.router import get_student_session  # noqa: E402
from app.config import settings  # noqa: E402

TEST_DB = os.environ.get("MED_TEST_DB", "med_companion_test")


def _connect():
    # قاعدة الاختبار المنفصلة فقط — لا تُستخدم بيانات القاعدة الفعلية.
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=TEST_DB,
        user=settings.db_user,
        password=settings.db_password.get_secret_value(),
        autocommit=False,
        row_factory=dict_row,
    )


class _CountingConn:
    """يغلّف الاتصال ليَعُدّ عدد استعلامات execute (لكشف N+1)."""

    def __init__(self, conn):
        self._conn = conn
        self.query_count = 0

    def execute(self, *args, **kwargs):
        self.query_count += 1
        return self._conn.execute(*args, **kwargs)

    def __getattr__(self, name):
        return getattr(self._conn, name)


@contextmanager
def seeded_tx():
    """معاملة على قاعدة الاختبار، يراها الـservice، وتتراجع في النهاية."""
    conn = _connect()
    counting = _CountingConn(conn)
    original = service.get_connection

    @contextmanager
    def _shared():
        yield counting

    service.get_connection = _shared
    try:
        yield conn, counting
    finally:
        service.get_connection = original
        conn.rollback()
        conn.close()


# ------------------------- دوال زرع البيانات -------------------------


def _mk_user(c, full_name, lang="en"):
    uid = c.execute(
        """
        INSERT INTO public.users (full_name, email, password_hash, role)
        VALUES (%s, %s, 'x', 'student') RETURNING id;
        """,
        (full_name, f"{full_name.replace(' ', '.').lower()}@test.local"),
    ).fetchone()["id"]
    c.execute(
        """
        INSERT INTO public.student_profiles
            (user_id, university, study_year, preferred_language)
        VALUES (%s, 'Test U', 3, %s);
        """,
        (uid, lang),
    )
    return uid


def _mk_subject(c, name_en, description=None):
    return c.execute(
        "INSERT INTO public.subjects (name_ar, name_en, description) "
        "VALUES (%s, %s, %s) RETURNING id;",
        (name_en + " AR", name_en, description),
    ).fetchone()["id"]


def _mk_topic(c, subject_id, name_en, order, description=None):
    return c.execute(
        "INSERT INTO public.topics (subject_id, name_ar, name_en, "
        "description, display_order) VALUES (%s,%s,%s,%s,%s) RETURNING id;",
        (subject_id, name_en + " AR", name_en, description, order),
    ).fetchone()["id"]


def _mk_lesson(c, topic_id, title_en, order, status="published",
               summary=None, with_content=False):
    lid = c.execute(
        "INSERT INTO public.lessons (topic_id, title_ar, title_en, summary, "
        "display_order, status) VALUES (%s,%s,%s,%s,%s,%s) RETURNING id;",
        (topic_id, title_en + " AR", title_en, summary, order, status),
    ).fetchone()["id"]
    if with_content:
        _mk_block(c, lid)
    return lid


def _mk_block(c, lesson_id, order=1):
    # بلوك محتوى نصّي يجعل الدرس "متاحًا للدراسة" (is_available=true).
    c.execute(
        "INSERT INTO public.lesson_blocks (lesson_id, block_type, "
        "text_content, display_order) VALUES (%s,'text','content',%s);",
        (lesson_id, order),
    )


def _mk_progress(c, sid, lesson_id, status):
    completed = "CURRENT_TIMESTAMP" if status == "completed" else "NULL"
    c.execute(
        f"""
        INSERT INTO public.lesson_progress
            (student_id, lesson_id, status, started_at, last_accessed_at,
             completed_at)
        VALUES (%s, %s, %s, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                {completed});
        """,
        (sid, lesson_id, status),
    )


# ------------------------------ المدقّق ------------------------------

_results = []


def check(label, cond, extra=""):
    _results.append((bool(cond), label))
    print(("PASS" if cond else "FAIL"), label, ("- " + str(extra)) if extra else "")
    return bool(cond)


# ------------------------------ الاختبارات ------------------------------


def test_subjects_published_only_and_counts():
    """(1,2,3) قائمة المواد: المنشورة فقط + العدّادات + available_lessons_count."""
    with seeded_tx() as (c, _):
        s1 = _mk_subject(c, "Cardiovascular System", "desc1")
        t1a = _mk_topic(c, s1, "Heart", 1)
        t1b = _mk_topic(c, s1, "Vessels", 2)
        _mk_lesson(c, t1a, "Chambers", 1, with_content=True)   # متاح
        _mk_lesson(c, t1a, "Valves", 2, with_content=False)    # Coming soon
        _mk_lesson(c, t1a, "Draft One", 3, status="draft")     # مُقصى
        _mk_lesson(c, t1b, "Only Draft", 1, status="draft")    # topic بلا منشور
        # مادة بلا أي درس منشور ⇒ يجب ألّا تظهر إطلاقًا.
        s2 = _mk_subject(c, "Empty Subject")
        t2 = _mk_topic(c, s2, "Ghost Topic", 1)
        _mk_lesson(c, t2, "Archived", 1, status="archived")

        result = service.list_published_subjects()

        ids = [s["id"] for s in result]
        check("only subject with published lessons is listed",
              ids == [s1], ids)
        item = result[0]
        check("topics_count counts only topics with published lessons (=1)",
              item["topics_count"] == 1, item["topics_count"])
        check("lessons_count = published lessons listed incl coming-soon (=2)",
              item["lessons_count"] == 2, item["lessons_count"])
        check("available_lessons_count = lessons with content only (=1)",
              item["available_lessons_count"] == 1,
              item["available_lessons_count"])
        check("title always English + description + null thumbnail",
              item["title"] == "Cardiovascular System"
              and item["description"] == "desc1"
              and item["thumbnail_url"] is None, item)


def test_subjects_order():
    """(4) ترتيب المواد تصاعديًا بالـid (لا عمود display_order للمواد)."""
    with seeded_tx() as (c, _):
        # ندرج "Beta" قبل "Alpha" ليثبت أن الترتيب بالـid لا بالاسم.
        sb = _mk_subject(c, "Beta")
        sa = _mk_subject(c, "Alpha")
        for sid in (sb, sa):
            t = _mk_topic(c, sid, "T", 1)
            _mk_lesson(c, t, f"L{sid}", 1, with_content=True)

        ids = [s["id"] for s in service.list_published_subjects()]
        check("subjects ordered by id ascending", ids == [sb, sa], ids)


def test_outline_published_only_and_order():
    """(5,6) المخطط: مواضيع/دروس منشورة فقط + ترتيب صحيح."""
    with seeded_tx() as (c, _):
        s = _mk_subject(c, "Subject", "sdesc")
        # نُدرج الموضوعين بترتيب عرض معكوس لإثبات الترتيب بـdisplay_order.
        t2 = _mk_topic(c, s, "Second", 2, "t2desc")
        t1 = _mk_topic(c, s, "First", 1, "t1desc")
        t_empty = _mk_topic(c, s, "NoPublished", 3)
        # دروس t1 بترتيب معكوس أيضًا.
        _mk_lesson(c, t1, "B", 2, with_content=True)
        _mk_lesson(c, t1, "A", 1, with_content=True)
        _mk_lesson(c, t1, "Draft", 3, status="draft")       # مُقصى
        _mk_lesson(c, t2, "C", 1, with_content=True)
        _mk_lesson(c, t_empty, "Arch", 1, status="archived")  # الموضوع مُقصى

        u = _mk_user(c, "Outline Student", "en")
        out = service.get_subject_outline(s, u)

        topic_ids = [t["id"] for t in out["topics"]]
        check("topics ordered by display_order (First then Second)",
              topic_ids == [t1, t2], topic_ids)
        check("topic with no published lessons is excluded",
              t_empty not in topic_ids, topic_ids)
        first_titles = [l["title"] for l in out["topics"][0]["lessons"]]
        check("lessons ordered by display_order (A then B), draft excluded",
              first_titles == ["A", "B"], first_titles)
        check("outline subject fields present (English title)",
              out["id"] == s and out["title"] == "Subject"
              and out["description"] == "sdesc", out["title"])
        check("outline lesson description comes from summary (null here)",
              out["topics"][0]["lessons"][0]["description"] is None)


def test_lesson_status_values():
    """(7,8,9) حالات not_started / in_progress / completed تظهر صحيحة."""
    with seeded_tx() as (c, _):
        s = _mk_subject(c, "StatusSubj")
        t = _mk_topic(c, s, "T", 1)
        l1 = _mk_lesson(c, t, "L1", 1, with_content=True)
        l2 = _mk_lesson(c, t, "L2", 2, with_content=True)
        l3 = _mk_lesson(c, t, "L3", 3, with_content=True)

        u = _mk_user(c, "Status Student", "en")
        _mk_progress(c, u, l2, "in_progress")
        _mk_progress(c, u, l3, "completed")

        out = service.get_subject_outline(s, u)
        by_id = {l["id"]: l["status"] for l in out["topics"][0]["lessons"]}
        check("no progress row -> not_started", by_id[l1] == "not_started")
        check("in_progress -> in_progress", by_id[l2] == "in_progress")
        check("completed -> completed", by_id[l3] == "completed")


def test_topic_progress_available_only():
    """(10) تقدّم الموضوع = مكتمل متاح / متاح فقط، ولا يتجاوز 100."""
    with seeded_tx() as (c, _):
        s = _mk_subject(c, "ProgSubj")
        t = _mk_topic(c, s, "T", 1)
        p1 = _mk_lesson(c, t, "P1", 1, with_content=True)
        p2 = _mk_lesson(c, t, "P2", 2, with_content=True)
        _mk_lesson(c, t, "P3", 3, with_content=True)
        p4 = _mk_lesson(c, t, "P4draft", 4, status="draft")

        u = _mk_user(c, "Prog Student", "en")
        _mk_progress(c, u, p1, "completed")
        _mk_progress(c, u, p2, "completed")
        _mk_progress(c, u, p4, "completed")  # درس draft ⇒ لا يُحتسب

        out = service.get_subject_outline(s, u)
        topic = out["topics"][0]
        check("lessons_count counts published listed only (=3)",
              topic["lessons_count"] == 3, topic["lessons_count"])
        check("available_lessons_count = lessons with content (=3)",
              topic["available_lessons_count"] == 3,
              topic["available_lessons_count"])
        check("completed_lessons counts published completions only (=2)",
              topic["completed_lessons"] == 2, topic["completed_lessons"])
        check("progress = 2/3 = 66.67 (<=100)",
              topic["progress_percentage"] == 66.67,
              topic["progress_percentage"])


def test_coming_soon_separation():
    """(11جديد) فصل الإتاحة عن التقدّم: Coming soon يُعرَض ولا يُحتسب."""
    with seeded_tx() as (c, _):
        s = _mk_subject(c, "ComingSoonSubj")
        t = _mk_topic(c, s, "T", 1)
        ready = _mk_lesson(c, t, "Ready", 1, with_content=True)
        soon = _mk_lesson(c, t, "Soon", 2, with_content=False)

        u = _mk_user(c, "CS Student", "en")
        _mk_progress(c, u, ready, "completed")
        # درس Coming soon مع صف تقدّم completed شاذّ ⇒ لا يُحتسب في النسبة.
        _mk_progress(c, u, soon, "completed")

        out = service.get_subject_outline(s, u)
        topic = out["topics"][0]
        lessons = {l["id"]: l for l in topic["lessons"]}
        check("both lessons are listed (titles shown)",
              len(topic["lessons"]) == 2, len(topic["lessons"]))
        check("ready lesson is_available = True",
              lessons[ready]["is_available"] is True)
        check("coming-soon lesson is_available = False",
              lessons[soon]["is_available"] is False)
        check("available_lessons_count excludes coming-soon (=1)",
              topic["available_lessons_count"] == 1,
              topic["available_lessons_count"])
        check("completed over available only: 1/1 = 100 (soon not counted)",
              topic["completed_lessons"] == 1
              and topic["progress_percentage"] == 100.0,
              (topic["completed_lessons"], topic["progress_percentage"]))
        check("coming-soon status still reflects progress field",
              lessons[soon]["status"] == "completed")


def test_titles_always_english():
    """(12جديد) العناوين إنجليزية دائمًا حتى مع preferred_language=ar."""
    with seeded_tx() as (c, _):
        s = _mk_subject(c, "English Subject")
        t = _mk_topic(c, s, "English Topic", 1)
        _mk_lesson(c, t, "English Lesson", 1, with_content=True)

        u = _mk_user(c, "Arabic Pref Student", "ar")
        subjects = service.list_published_subjects()
        out = service.get_subject_outline(s, u)
        check("subjects list title is English (not *_ar)",
              subjects[0]["title"] == "English Subject")
        check("outline subject/topic/lesson titles are English",
              out["title"] == "English Subject"
              and out["topics"][0]["title"] == "English Topic"
              and out["topics"][0]["lessons"][0]["title"] == "English Lesson")


def test_isolation_between_students():
    """(13) تقدّم الطالب A لا يظهر للطالب B."""
    with seeded_tx() as (c, _):
        s = _mk_subject(c, "IsoSubj")
        t = _mk_topic(c, s, "T", 1)
        l1 = _mk_lesson(c, t, "L1", 1, with_content=True)

        a = _mk_user(c, "Iso A", "en")
        b = _mk_user(c, "Iso B", "en")
        _mk_progress(c, a, l1, "completed")

        out_a = service.get_subject_outline(s, a)
        out_b = service.get_subject_outline(s, b)
        check("A sees completed", out_a["topics"][0]["lessons"][0]["status"]
              == "completed")
        check("B sees not_started (A's progress hidden)",
              out_b["topics"][0]["lessons"][0]["status"] == "not_started")
        check("B topic progress = 0",
              out_b["topics"][0]["progress_percentage"] == 0.0)


def test_get_is_read_only():
    """(14) تنفيذ GET لا يكتب أي صف (lesson_progress خصوصًا)."""
    with seeded_tx() as (c, _):
        s = _mk_subject(c, "ReadOnlySubj")
        t = _mk_topic(c, s, "T", 1)
        _mk_lesson(c, t, "L1", 1, with_content=True)
        u = _mk_user(c, "ReadOnly Student", "en")

        before = c.execute(
            "SELECT count(*) n FROM public.lesson_progress "
            "WHERE student_id = %s;", (u,)).fetchone()["n"]
        service.list_published_subjects()
        service.get_subject_outline(s, u)
        after = c.execute(
            "SELECT count(*) n FROM public.lesson_progress "
            "WHERE student_id = %s;", (u,)).fetchone()["n"]
        check("GET created no lesson_progress rows",
              before == 0 and after == 0, (before, after))


def test_subject_404():
    """(15) مادة غير موجودة أو غير منشورة (بلا دروس منشورة) ⇒ 404."""
    from fastapi import HTTPException

    with seeded_tx() as (c, _):
        u = _mk_user(c, "NotFound Student", "en")

        raised = False
        try:
            service.get_subject_outline(999999, u)
        except HTTPException as exc:
            raised = exc.status_code == 404
        check("missing subject id -> 404", raised)

        # مادة موجودة لكن كل دروسها غير منشورة ⇒ تُعدّ غير منشورة ⇒ 404.
        s = _mk_subject(c, "DraftOnlySubj")
        t = _mk_topic(c, s, "T", 1)
        _mk_lesson(c, t, "D", 1, status="draft")
        raised2 = False
        try:
            service.get_subject_outline(s, u)
        except HTTPException as exc:
            raised2 = exc.status_code == 404
        check("existing subject with no published lessons -> 404", raised2)


def test_no_n_plus_one():
    """(16) عدد الاستعلامات ثابت مهما زاد عدد الدروس (لا N+1)."""
    with seeded_tx() as (c, counting):
        s = _mk_subject(c, "ManySubj")
        t = _mk_topic(c, s, "T", 1)
        for i in range(1, 26):  # 25 درسًا منشورًا، بعضها بمحتوى
            _mk_lesson(c, t, f"L{i}", i, with_content=(i % 2 == 0))
        u = _mk_user(c, "NPlus Student", "en")

        counting.query_count = 0
        service.get_subject_outline(s, u)
        # ثابت: مادة + صفوف المخطط = استعلامان بغضّ النظر عن عدد الدروس.
        check("outline uses a constant number of queries (<=2)",
              counting.query_count <= 2, counting.query_count)

        counting.query_count = 0
        service.list_published_subjects()
        # ثابت: استعلام تجميع واحد.
        check("subjects list uses a single query",
              counting.query_count == 1, counting.query_count)


def test_auth_and_routes_unchanged():
    """(17) الحارس والمسارات السابقة لم تتغيّر + حارس الطالب 403."""
    from fastapi import HTTPException

    from app.main import app

    paths = set(app.openapi()["paths"].keys())
    expected = {
        "/auth/login", "/auth/me", "/auth/logout", "/auth/signup",
        "/students/me", "/students/me/profile-overview",
        "/learning/subjects", "/learning/subjects/{subject_id}/outline",
    }
    missing = expected - paths
    check("all expected routes present (old + new)", not missing, missing)

    # نفس حارس الطالب المُعاد استخدامه: غير الطالب ⇒ 403.
    raised = False
    try:
        get_student_session(session={"role": "admin", "id": 1})
    except HTTPException as exc:
        raised = exc.status_code == 403
    check("non-student session -> 403 (reused guard)", raised)


def run():
    try:
        _connect().close()
    except Exception as exc:  # noqa: BLE001
        print(f"SKIP: cannot reach test DB '{TEST_DB}': {exc}")
        print("Set MED_TEST_DB or create it from sql/000.")
        return

    test_subjects_published_only_and_counts()
    test_subjects_order()
    test_outline_published_only_and_order()
    test_lesson_status_values()
    test_topic_progress_available_only()
    test_coming_soon_separation()
    test_titles_always_english()
    test_isolation_between_students()
    test_get_is_read_only()
    test_subject_404()
    test_no_n_plus_one()
    test_auth_and_routes_unchanged()

    passed = sum(1 for ok, _ in _results if ok)
    print(f"\nALL_PASS {passed == len(_results)} ({passed}/{len(_results)})")
    assert passed == len(_results), "some checks failed"


if __name__ == "__main__":
    run()
