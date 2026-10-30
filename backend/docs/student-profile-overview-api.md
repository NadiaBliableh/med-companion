# Student Profile Overview API

مسار واحد يغذّي شاشة Profile في التطبيق. كل القيم تُحسب لحظيًا من قاعدة
البيانات ولا تُخزَّن في `student_profiles`.

- `GET /students/me/profile-overview`

يتطلب جلسة صالحة لمستخدم دوره `student` (نفس حارس `/students/me`).
`student_id` يؤخذ من الـBearer token فقط. الاستجابة تحمل `Cache-Control: no-store`.

## المصادقة

```
Authorization: Bearer <access_token>
```

التوكن من `POST /auth/login`. الأمثلة أدناه قيم توضيحية فقط.

## شكل الاستجابة (200)

```json
{
  "profile": {
    "full_name": "Wala Abu Jafar",
    "avatar_url": null,
    "study_year": 3,
    "preferred_language": "en"
  },
  "stats": {
    "current_streak_days": 12,
    "total_study_seconds": 27900,
    "overall_progress_percentage": 42.0
  },
  "continue_learning": {
    "subject_id": 1,
    "subject_title": "Cardiovascular System",
    "topic_id": 1,
    "topic_title": "Heart",
    "lesson_id": 2,
    "lesson_title": "Heart Anatomy",
    "lesson_order": 2,
    "lessons_count": 5,
    "status": "in_progress",
    "completed_lessons_in_topic": 1,
    "topic_progress_percentage": 20.0,
    "thumbnail_url": null
  },
  "weekly_activity": [
    { "date": "2026-10-24", "study_seconds": 0 },
    { "date": "2026-10-25", "study_seconds": 1800 },
    { "date": "2026-10-26", "study_seconds": 1200 },
    { "date": "2026-10-27", "study_seconds": 0 },
    { "date": "2026-10-28", "study_seconds": 3600 },
    { "date": "2026-10-29", "study_seconds": 600 },
    { "date": "2026-10-30", "study_seconds": 1800 }
  ],
  "saved_lessons_count": 8
}
```

## قواعد الحساب

| الحقل | القاعدة |
|------|---------|
| `total_study_seconds` | مجموع `accumulated_active_seconds` لجلسات `focus_sessions` حيث `status='completed'` و `phase='study'` لهذا الطالب فقط. تُستبعد جلسات `break`/`running`/`paused`/`cancelled`. |
| `weekly_activity` | مجموع وقت الدراسة لكل يوم خلال آخر 7 أيام (شامل اليوم)، اليوم محدَّد بتوقيت `Asia/Hebron` حسب `started_at`. الأيام بلا نشاط تظهر بـ `0`. |
| `current_streak_days` | أيام دراسة متتالية حتى اليوم. اليوم يُحسب إذا كان للطالب جلسة `study` مكتملة ≥ 300 ثانية **أو** أكمل درسًا في ذلك اليوم. إذا لم يدرس اليوم لكن درس أمس، لا يُكسر الـstreak. |
| `overall_progress_percentage` | (دروس الطالب المكتملة والمنشورة ÷ كل الدروس المنشورة) × 100. لا دروس منشورة ⇒ `0`. |
| `continue_learning` | آخر درس بدأه الطالب ولم يكمله (الأحدث حسب `last_accessed_at`)، **بشرط أن يكون منشورًا**؛ فإن أصبح غير منشور يُتخطّى. وإلا أول درس منشور غير مكتمل (بترتيب `subject_id`، `topics.display_order`، `lessons.display_order`)؛ وإذا أكمل الكل أو لا دروس منشورة ⇒ `null`. |
| `status` (داخل continue_learning) | حالة الدرس وفق `lesson_progress`: `in_progress` (له صف قيد التقدّم) أو `not_started` (لا صف). لا يكون `completed` أبدًا لأن الاختيار يستبعد المكتمل. |
| `lessons_count` (داخل continue_learning) | عدد الدروس **المنشورة والمتاحة** في نفس الـtopic (مقام تقدّم الـtopic، وهو الـ"5" في "Lesson 2 of 5"). لا يوجد حقل منفصل `published_lessons_in_topic` لأنه يحمل نفس القيمة. |
| `completed_lessons_in_topic` | عدد الدروس المنشورة في هذا الـtopic التي أكملها الطالب. |
| `topic_progress_percentage` | `completed_lessons_in_topic / lessons_count × 100`. تقدّم على مستوى الـtopic لتغذية شريط البطاقة. **ليس تقدّمًا داخل محتوى الدرس؛ لا يوجد استئناف من موضع محفوظ (لا تتبّع على مستوى blocks).** |

> **ملاحظة:** أُزيل حقل `progress_percentage` القديم لأنه كان `0` دائمًا (الاختيار يستبعد المكتمل) ومضلِّل. حالة الدرس تُقرأ من `status`، وتقدّم المسار من `topic_progress_percentage`.
| `saved_lessons_count` | عدد صفوف `saved_lessons` لهذا الطالب. |
| `lesson_order` / `lessons_count` | ترتيب الدرس وعدد الدروس **المنشورة** داخل نفس الـtopic. |
| `subject_title` / `topic_title` / `lesson_title` | عنوان مفرد حسب `preferred_language`: `ar` ⇒ `*_ar`، `en` ⇒ `*_en`. |
| `avatar_url` / `thumbnail_url` | غير مخزَّنين في المخطط الحالي ⇒ `null`. الواجهة تولّد الأحرف الأولى للأفاتار. |

## قيد معروف: دقّة توزيع الوقت على الأيام

المخطط الحالي لـ `focus_sessions` يخزّن **إجماليًا واحدًا** للوقت النشط
(`accumulated_active_seconds`) مع وقت بدء واحد (`started_at`)، **ولا يخزّن
فترات النشاط الفعلية** (pause/resume كأزواج بداية/نهاية).

لذلك:
- `weekly_activity` و`total_study_seconds` يُسنِدان **كامل** وقت الجلسة إلى
  **يوم البدء المحلي** (Asia/Hebron).
- جلسة تبدأ قبل منتصف الليل وتنتهي بعده، أو فيها pause/resume يعبر منتصف
  الليل، **لا يمكن تقسيم وقتها النشط بدقّة** بين اليومين من البيانات المتاحة.
- لم نقسّم الوقت تقديريًا ونقدّمه كأنه دقيق؛ نكتفي بإسناده ليوم البدء ونصرّح
  بذلك هنا.

**الوضع الحالي صريح: لا يحسب التوزيع اليومي بدقّة** عبر منتصف الليل أو مع
pause/resume؛ يُسنِد كامل وقت الجلسة ليوم بدايتها فقط، وهذا **مقبول مؤقتًا
لهذه المرحلة**.

### TODO (مهمة مستقبلية — غير منفَّذة الآن)

لحساب دقيق لوقت كل يوم محلي:

1. إضافة جدول `focus_intervals(session_id, started_at, ended_at)` يسجّل كل
   فترة نشاط فعلية بين resume و pause/stop.
2. ربطه بميزة **مؤقّت الدراسة** (Focus timer) بحيث تُكتب فترة عند كل
   pause/resume/stop.
3. إعادة حساب `weekly_activity` و `total_study_seconds` و `current_streak_days`
   بتقاطع كل فترة مع حدود اليوم المحلي (Asia/Hebron)، بدل إسناد يوم البدء.
4. إضافة اختبارات: جلسة تعبر منتصف الليل، وجلسة فيها pause/resume متعدّد.

هذا تغيير مخطط جديد خارج نطاق هذه الخطوة.

تأثير ذلك على `current_streak_days` أقل (دقّة يوم واحد): يوم البدء هو ما
يُحتسب، وقد لا يطابق اليوم الذي جرى فيه معظم النشاط عبر منتصف الليل.

## الحالات الفارغة

- لا نشاط ⇒ `total_study_seconds=0`، `current_streak_days=0`، و7 أيام بـ `0`.
- لا دروس منشورة ⇒ `overall_progress_percentage=0`، `continue_learning=null`.
- لا محفوظات ⇒ `saved_lessons_count=0`.

## الأخطاء

| الرمز | المعنى |
|------|--------|
| `401` | توكن مفقود/غير صالح/منتهٍ |
| `403` | الجلسة صالحة لكن الدور ليس `student` |
| `404` | لا يوجد ملف طالب للمستخدم |

## أمثلة اختبار من Swagger

1. شغّل الباك: `.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8001`
2. افتح `http://127.0.0.1:8001/docs`.
3. `POST /auth/login` ببريد وكلمة مرور طالب ⇒ انسخ `access_token`.
4. اضغط **Authorize** وألصق التوكن (بدون كلمة `Bearer`؛ Swagger يضيفها).
5. نفّذ `GET /students/me/profile-overview` وتحقق من البنية أعلاه.
