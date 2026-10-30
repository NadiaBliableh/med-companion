"""اختبارات GET /students/me/profile-overview.

تعمل على **قاعدة اختبار منفصلة** فقط (لا تلمس القاعدة الفعلية إطلاقًا):
اسمها من المتغيّر البيئي MED_TEST_DB، وافتراضيًا "med_companion_test".
إن تعذّر الاتصال بها تُتخطّى الاختبارات (دون أي كتابة على القاعدة الحقيقية).

كل اختبار يزرع بياناته داخل معاملة واحدة لا تُحفظ (rollback في النهاية)،
ويوجّه اتصال الـservice إلى نفس المعاملة ليرى البيانات المزروعة.

تهيئة قاعدة الاختبار لمرة واحدة (CREATE DATABASE ثم تحميل المخطط):
    sql/000_med_companion_full_schema.sql
    sql/002_focus_sessions_and_saved_lessons.sql

التشغيل (pytest غير مثبّت):
    .\\.venv\\Scripts\\python.exe tests\\test_profile_overview.py
مع pytest إن ثُبِّت:
    .\\.venv\\Scripts\\python.exe -m pytest tests/test_profile_overview.py -v
"""

import os
import sys
from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import settings  # noqa: E402
from app.students import service  # noqa: E402

TZ = "Asia/Hebron"
TEST_DB = os.environ.get("MED_TEST_DB", "med_companion_test")

# started_at عند ظهر اليوم المحلي قبل N يومًا (نتجنّب حافة منتصف الليل/DST).
_LOCAL_DAY = (
    "((CURRENT_TIMESTAMP AT TIME ZONE %(tz)s)::date "
    "- make_interval(days => %(n)s) + time '12:00') AT TIME ZONE %(tz)s"
)


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


@contextmanager
def seeded_tx():
    """معاملة على قاعدة الاختبار، يراها الـservice، وتتراجع في النهاية."""
    conn = _connect()
    original = service.get_connection

    @contextmanager
    def _shared():
        yield conn

    service.get_connection = _shared
    try:
        yield conn
    finally:
        service.get_connection = original
        conn.rollback()
        conn.close()


# ------------------------- دوال زرع البيانات -------------------------


def _mk_user(c, full_name, year, lang):
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
        VALUES (%s, 'Test U', %s, %s);
        """,
        (uid, year, lang),
    )
    return uid


def _mk_subject(c, name_en):
    return c.execute(
        "INSERT INTO public.subjects (name_ar, name_en) VALUES (%s,%s) "
        "RETURNING id;",
        (name_en + " AR", name_en),
    ).fetchone()["id"]


def _mk_topic(c, subject_id, name_en, order):
    return c.execute(
        "INSERT INTO public.topics (subject_id, name_ar, name_en, "
        "display_order) VALUES (%s,%s,%s,%s) RETURNING id;",
        (subject_id, name_en + " AR", name_en, order),
    ).fetchone()["id"]


def _mk_lesson(c, topic_id, title_en, order, status="published"):
    return c.execute(
        "INSERT INTO public.lessons (topic_id, title_ar, title_en, "
        "display_order, status) VALUES (%s,%s,%s,%s,%s) RETURNING id;",
        (topic_id, title_en + " AR", title_en, order, status),
    ).fetchone()["id"]


def _mk_progress(c, sid, lesson_id, status):
    completed = _LOCAL_DAY if status == "completed" else "NULL"
    c.execute(
        f"""
        INSERT INTO public.lesson_progress
            (student_id, lesson_id, status, started_at, last_accessed_at,
             completed_at)
        VALUES (%(sid)s, %(lid)s, %(st)s,
                {_LOCAL_DAY}, {_LOCAL_DAY}, {completed});
        """,
        {"sid": sid, "lid": lesson_id, "st": status, "tz": TZ, "n": 0},
    )


def _mk_focus(c, sid, days_ago, seconds, phase="study", status="completed"):
    ended = (
        f"{_LOCAL_DAY} + make_interval(secs => %(secs)s)"
        if status in ("completed", "cancelled")
        else "NULL"
    )
    c.execute(
        f"""
        INSERT INTO public.focus_sessions
            (student_id, lesson_id, phase, planned_seconds, status,
             started_at, accumulated_active_seconds, ended_at, version)
        VALUES (%(sid)s, NULL, %(phase)s, 3600, %(status)s,
                {_LOCAL_DAY}, %(secs)s, {ended}, 1);
        """,
        {"sid": sid, "phase": phase, "status": status, "tz": TZ,
         "n": days_ago, "secs": seconds},
    )


def _mk_saved(c, sid, lesson_id):
    c.execute(
        "INSERT INTO public.saved_lessons (student_id, lesson_id) "
        "VALUES (%s,%s);",
        (sid, lesson_id),
    )


# ------------------------------ المدقّق ------------------------------

_results = []


def check(label, cond, extra=""):
    _results.append((bool(cond), label))
    print(("PASS" if cond else "FAIL"), label, ("- " + str(extra)) if extra else "")
    return bool(cond)


# ------------------------------ الاختبارات ------------------------------


def test_overview_calculations():
    """الحسابات الأساسية + العزل لطالبين (الـ14 اختبارًا الأصلية + status)."""
    with seeded_tx() as c:
        subj = _mk_subject(c, "Cardiovascular System")
        topic = _mk_topic(c, subj, "Heart", 0)
        l1 = _mk_lesson(c, topic, "Intro", 1)
        l2 = _mk_lesson(c, topic, "Heart Anatomy", 2)
        _mk_lesson(c, topic, "Vessels", 3)
        _mk_lesson(c, topic, "Circulation", 4)
        _mk_lesson(c, topic, "ECG", 5)
        _mk_lesson(c, topic, "Draft Lesson", 6, status="draft")
        published_total = c.execute(
            "SELECT count(*) n FROM public.lessons WHERE status='published'"
        ).fetchone()["n"]

        a = _mk_user(c, "Student A", 3, "en")
        _mk_progress(c, a, l1, "completed")
        _mk_progress(c, a, l2, "in_progress")
        _mk_focus(c, a, 0, 1800)
        _mk_focus(c, a, 1, 600)
        _mk_focus(c, a, 2, 300)
        _mk_focus(c, a, 10, 1200)
        _mk_focus(c, a, 0, 1000, phase="break")
        _mk_focus(c, a, 0, 999, status="running")
        _mk_focus(c, a, 1, 800, status="cancelled")
        _mk_saved(c, a, l1)
        _mk_saved(c, a, l2)

        b = _mk_user(c, "Student B", 1, "ar")
        _mk_focus(c, b, 0, 500)
        _mk_saved(c, b, l1)

        a_ov = service.get_profile_overview(a)
        b_ov = service.get_profile_overview(b)
        cl = a_ov["continue_learning"]

        check("A total_study_seconds = 3900 (break/running/cancelled excluded)",
              a_ov["stats"]["total_study_seconds"] == 3900,
              a_ov["stats"]["total_study_seconds"])
        check("A streak = 3",
              a_ov["stats"]["current_streak_days"] == 3)
        check("A overall_progress = completed/published",
              a_ov["stats"]["overall_progress_percentage"]
              == round(1 / published_total * 100, 2),
              a_ov["stats"]["overall_progress_percentage"])
        check("A continue = Heart Anatomy (en), order 2 of 5",
              cl and cl["lesson_title"] == "Heart Anatomy"
              and cl["subject_title"] == "Cardiovascular System"
              and cl["lesson_order"] == 2 and cl["lessons_count"] == 5,
              cl)
        check("A weekly has 7 days, today=1800, sum=2700",
              len(a_ov["weekly_activity"]) == 7
              and a_ov["weekly_activity"][-1]["study_seconds"] == 1800
              and sum(d["study_seconds"] for d in a_ov["weekly_activity"]) == 2700)
        check("A saved_lessons_count = 2",
              a_ov["saved_lessons_count"] == 2)
        check("A profile avatar_url null, lang en, year 3",
              a_ov["profile"]["avatar_url"] is None
              and a_ov["profile"]["preferred_language"] == "en"
              and a_ov["profile"]["study_year"] == 3)
        check("B total_study_seconds = 500 (only B's own)",
              b_ov["stats"]["total_study_seconds"] == 500)
        check("B streak = 1",
              b_ov["stats"]["current_streak_days"] == 1)
        check("B saved_lessons_count = 1",
              b_ov["saved_lessons_count"] == 1)
        check("B overall_progress = 0 (no completed)",
              b_ov["stats"]["overall_progress_percentage"] == 0.0)
        check("B titles in Arabic (preferred_language=ar)",
              b_ov["continue_learning"] is None
              or b_ov["continue_learning"]["subject_title"].endswith("AR"))
        check("isolation: A and B totals differ",
              a_ov["stats"]["total_study_seconds"]
              != b_ov["stats"]["total_study_seconds"])
        check("isolation: B saved != A saved",
              b_ov["saved_lessons_count"] != a_ov["saved_lessons_count"])
        # إضافة المراجعة: حالة درس المتابعة صريحة (in_progress هنا).
        check("A continue status = in_progress (explicit lesson state)",
              cl and cl["status"] == "in_progress", cl and cl["status"])
        # تقدّم على مستوى الـtopic: أكمل درسًا واحدًا من 5 منشورة = 20%.
        check("A topic progress = 1/5 = 20% (no in-content progress)",
              cl and cl["completed_lessons_in_topic"] == 1
              and cl["topic_progress_percentage"] == 20.0,
              cl and (cl["completed_lessons_in_topic"],
                      cl["topic_progress_percentage"]))


def test_unpublished_in_progress_is_skipped():
    """درس in_progress أصبح غير منشور يُتخطّى إلى الدرس المنشور التالي."""
    with seeded_tx() as c:
        subj = _mk_subject(c, "Subject X")
        topic = _mk_topic(c, subj, "Topic X", 0)
        archived = _mk_lesson(c, topic, "Archived Lesson", 1, status="archived")
        published = _mk_lesson(c, topic, "Published Lesson", 2, status="published")

        s = _mk_user(c, "Student C", 2, "en")
        _mk_progress(c, s, archived, "in_progress")  # قيد التقدّم لكنه مؤرشَف

        ov = service.get_profile_overview(s)
        cl = ov["continue_learning"]
        check("continue skips archived in_progress lesson",
              cl is not None and cl["lesson_id"] != archived, cl)
        check("continue falls back to the published lesson",
              cl is not None and cl["lesson_id"] == published, cl)
        check("fallback lesson status = not_started, topic progress 0",
              cl is not None and cl["status"] == "not_started"
              and cl["completed_lessons_in_topic"] == 0
              and cl["topic_progress_percentage"] == 0.0)


def test_overall_filters_consistent():
    """بسط ومقام overall_progress يطبّقان نفس فلتر الإتاحة (published)."""
    with seeded_tx() as c:
        subj = _mk_subject(c, "Subject Y")
        topic = _mk_topic(c, subj, "Topic Y", 0)
        pub = _mk_lesson(c, topic, "Pub", 1, status="published")
        arch = _mk_lesson(c, topic, "Arch", 2, status="archived")

        s = _mk_user(c, "Student D", 2, "en")
        _mk_progress(c, s, pub, "completed")    # مكتمل ومنشور ⇒ يُحتسب
        _mk_progress(c, s, arch, "completed")   # مكتمل لكنه مؤرشَف ⇒ لا يُحتسب

        ov = service.get_profile_overview(s)
        # منشور واحد فقط، ومكتمل منشور واحد ⇒ 100% (المؤرشَف لا يرفع فوق 100).
        check("overall counts only published completions (no >100%)",
              ov["stats"]["overall_progress_percentage"] == 100.0,
              ov["stats"]["overall_progress_percentage"])


def test_empty_state():
    """طالب بلا أي نشاط: أصفار + continue null + 7 أيام أصفار."""
    with seeded_tx() as c:
        s = _mk_user(c, "Student E", 4, "ar")
        ov = service.get_profile_overview(s)
        check("empty: zeros, continue null, 7 zero days",
              ov["stats"]["total_study_seconds"] == 0
              and ov["stats"]["current_streak_days"] == 0
              and ov["stats"]["overall_progress_percentage"] == 0.0
              and ov["continue_learning"] is None
              and ov["saved_lessons_count"] == 0
              and len(ov["weekly_activity"]) == 7
              and all(d["study_seconds"] == 0 for d in ov["weekly_activity"]))


def run():
    try:
        _connect().close()
    except Exception as exc:  # noqa: BLE001
        print(f"SKIP: cannot reach test DB '{TEST_DB}': {exc}")
        print("Set MED_TEST_DB or create it from sql/000 + sql/002.")
        return

    test_overview_calculations()
    test_unpublished_in_progress_is_skipped()
    test_overall_filters_consistent()
    test_empty_state()

    passed = sum(1 for ok, _ in _results if ok)
    print(f"\nALL_PASS {passed == len(_results)} ({passed}/{len(_results)})")
    assert passed == len(_results), "some checks failed"


if __name__ == "__main__":
    run()
