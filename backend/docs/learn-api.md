# Learn API — تسليم أول واجهتين (لنادية / الفرونت إند)

ثلاثة مسارات تغذّي قسم Learn:

- `GET /learning/subjects` — شاشة Learn Home (قائمة المواد).
- `GET /learning/subjects/{subject_id}/outline` — شاشة Subject Outline
  (المواضيع ودروسها وحالة كل درس للطالب).
- `GET /learning/lessons/{lesson_id}` — تفاصيل درس وأقسامه المرتبة (حاليًا
  قسم Overview). متاح فقط للدروس الجاهزة؛ غير ذلك `404`.

كل القيم تُحسب لحظيًا. الاستجابات للقراءة فقط: تنفيذ GET لا يُنشئ ولا يعدّل
أي صف (لا يُنشئ `lesson_progress`). كل استجابة تحمل `Cache-Control: no-store`.

## المصادقة

```
Authorization: Bearer <access_token>
```

- التوكن من `POST /auth/login`.
- للطلاب فقط (`role = student`)؛ هوية الطالب من التوكن فقط، لا تُرسل
  `student_id`.
- **العناوين تُعاد بالإنجليزية دائمًا** (`name_en`/`title_en`) بغضّ النظر عن
  `preferred_language`. تبديل لغة الواجهة مسؤولية الفرونت.

---

## ثلاثة أبعاد مستقلّة لكل درس

1. **`can_open`** — هل يمكن فتح الدرس وعرض محتواه الحالي؟ = منشور **وله محتوى**.
   **هذا ما يُشغّل/يُعطّل زرّ الدرس.**
   - `true` → الزر مُفعّل، افتحي `GET /learning/lessons/{id}`.
   - `false` → **"Coming soon"**: اعرضي العنوان و**عطّلي الزر**. فتحه يُعيد `404`.
2. **`is_available`** — هل اكتمل تجهيز الدرس للدراسة؟ (قرار صريح، `is_content_ready`.)
   - يقود التقدّم والمتابعة فقط.
   - إذا `can_open=true` و`is_available=false` ⇒ الدرس يُفتح لكن محتواه جزئي:
     اعرضي داخله عبارة **"More sections coming soon"**.
3. **`status`** — تقدّم هذا الطالب في الدرس: `not_started`/`in_progress`/`completed`.
   مستقلّ عن البُعدين أعلاه.

> الحالات الثلاث لدرس منشور:
> - بلا محتوى → `can_open=false`, `is_available=false` → "Coming soon" (زر معطّل).
> - له محتوى، غير مكتمل → `can_open=true`, `is_available=false` → يُفتح + "More sections coming soon".
> - له محتوى، مكتمل → `can_open=true`, `is_available=true` → متاح بالكامل.

العدّادات تفرّق بين:
- **المعروض** (`lessons_count`): كل الدروس المنشورة في القائمة.
- **المتاح للدراسة** (`available_lessons_count`): الدروس الجاهزة (`is_available`)
  فقط. وهو **مقام نسبة التقدّم** (لا علاقة له بـ`can_open`).

---

## 1) GET /learning/subjects

### مثال الاستجابة (200)

```json
{
  "subjects": [
    {
      "id": 1,
      "title": "Cardiovascular System",
      "description": "Explore heart anatomy and function.",
      "thumbnail_url": null,
      "topics_count": 1,
      "lessons_count": 3,
      "available_lessons_count": 1
    }
  ]
}
```

### القواعد
- تُعاد المواد المنشورة فقط (مادة فيها درس منشور واحد على الأقل).
- `topics_count`: عدد المواضيع التي تحوي درسًا منشورًا داخل المادة.
- `lessons_count`: عدد الدروس المنشورة المعروضة (شامل Coming soon).
- `available_lessons_count`: عدد الدروس الجاهزة للدراسة فعلًا.
- الترتيب حسب `id` تصاعديًا.
- لا توجد مواد ⇒ `{ "subjects": [] }`.

---

## 2) GET /learning/subjects/{subject_id}/outline

### مثال الاستجابة (200)

```json
{
  "id": 1,
  "title": "Cardiovascular System",
  "description": "Explore heart anatomy and function.",
  "topics": [
    {
      "id": 1,
      "title": "Heart Structure & Blood Flow",
      "description": "Chambers, valves and the pathway of blood.",
      "display_order": 1,
      "lessons_count": 3,
      "available_lessons_count": 0,
      "completed_lessons": 0,
      "progress_percentage": 0.0,
      "lessons": [
        {
          "id": 1,
          "title": "Heart Chambers",
          "description": "Identify the four chambers and understand their basic roles.",
          "display_order": 1,
          "status": "not_started",
          "can_open": true,
          "is_available": false,
          "thumbnail_url": null
        },
        {
          "id": 2,
          "title": "Heart Valves & Great Vessels",
          "description": "Explore heart valves and the major vessels connected to the heart.",
          "display_order": 2,
          "status": "not_started",
          "can_open": false,
          "is_available": false,
          "thumbnail_url": null
        },
        {
          "id": 3,
          "title": "Blood Flow Through the Heart",
          "description": "Trace the path of blood through the heart.",
          "display_order": 3,
          "status": "not_started",
          "can_open": false,
          "is_available": false,
          "thumbnail_url": null
        }
      ]
    }
  ]
}
```

### سلوك زر الدرس (مهم) — يعتمد على `can_open`
| `can_open` | `is_available` | العرض | الزر |
|-----------|----------------|-------|------|
| `false` | `false` | عنوان + شارة **"Coming soon"** | **مُعطّل** |
| `true` | `false` | يُفتح، وداخله **"More sections coming soon"** | مُفعّل |
| `true` | `true` | يُفتح بالكامل | مُفعّل |

> تفعيل الزر = `can_open`. أمّا `is_available` فيخصّ اكتمال التجهيز (ويقود
> التقدّم/المتابعة)، ويظهر داخل الدرس كـ "More sections coming soon" عند
> `can_open=true && !is_available`.

### معنى `status` (تقدّم الطالب فقط، لهذا الطالب)
| القيمة | المعنى |
|-------|--------|
| `not_started` | لا يوجد صف تقدّم للطالب على هذا الدرس |
| `in_progress` | الطالب بدأ الدرس ولم يُكمله |
| `completed` | الطالب أكمل الدرس |

> لا تظهر حالة أي طالب آخر؛ العزل تام حسب التوكن.

### قواعد التقدّم (لكل Topic)
- `lessons_count` = عدد الدروس المنشورة المعروضة (= طول `lessons`، شامل Coming soon).
- `available_lessons_count` = الدروس الجاهزة للدراسة.
- `completed_lessons` = الدروس **الجاهزة** التي أكملها الطالب.
- `progress_percentage` = `completed_lessons / available_lessons_count × 100`
  (مقرّبة لخانتين). إذا `available_lessons_count = 0` ⇒ `0`. لا تتجاوز `100`.

### قواعد الإتاحة والترتيب
- تظهر المواضيع التي تحوي درسًا منشورًا واحدًا على الأقل فقط.
- تظهر الدروس المنشورة فقط (تُستبعد `draft` و`archived`).
- ترتيب المواضيع: `display_order` ثم `id`. ترتيب الدروس: `display_order` ثم `id`.

---

## 3) GET /learning/lessons/{lesson_id}

تفاصيل درس وأقسامه المرتبة. **يُفتح لأي درس منشور قابل للفتح** (`can_open=true`،
أي له محتوى) حتى لو لم يكتمل تجهيزه (`is_available=false`) — دعمًا لعرض المحتوى
تدريجيًا. يُعيد **`404`** إذا: الدرس غير منشور، **أو** منشور بلا محتوى
(`can_open=false`، "Coming soon"). فلا تفتحي درسًا `can_open=false` من الـoutline.

### مثال الاستجابة (200) — Heart Chambers (قابل للفتح، غير مكتمل بعد)
```json
{
  "id": 13,
  "title": "Heart Chambers",
  "description": "Identify the four chambers and understand their basic roles.",
  "can_open": true,
  "is_available": false,
  "status": "not_started",
  "sections": [
    {
      "key": "overview",
      "display_order": 1,
      "blocks": [
        {
          "display_order": 1,
          "block_type": "text",
          "title": "Heart Chambers",
          "text": "Explore the four chambers of the heart and how they work together.",
          "resource_url": null,
          "alternative_text": null
        },
        {
          "display_order": 2,
          "block_type": "text",
          "title": "Learning objectives",
          "text": "Name the four chambers of the heart.\nLocate each chamber on a labelled diagram and a 3D model.\nDistinguish the roles of the atria and ventricles.",
          "resource_url": null,
          "alternative_text": null
        }
      ]
    }
  ]
}
```

### كيف تعرضين قسم Overview
- `sections` قائمة أقسام مرتبة بـ`display_order`. حاليًا قسم واحد `key="overview"`.
- داخل القسم `blocks` مرتبة بـ`display_order`:
  - البلوك الأول: `title` = عنوان القسم، `text` = مقدّمة Overview.
  - البلوك الثاني (`title="Learning objectives"`): `text` يحتوي **الأهداف،
    هدفًا لكلّ سطر** — قسّميه على `\n` واعرضيه كنقاط.
- `block_type` قد يكون لاحقًا `image`/`video`/`model_3d` مع `resource_url`؛
  حاليًا كله `text`. **لا توجد روابط وهمية** (`resource_url=null`).
- عندما `is_available=false` اعرضي بعد الأقسام الموجودة عبارة
  **"More sections coming soon"**.

---

## الحقول التي تكون null حاليًا
- `thumbnail_url` (للمادة وللدرس): غير مخزَّن في المخطط ⇒ **null دائمًا**.
  استخدمي صورة/أيقونة بديلة.
- `description`: قد يكون `null` إذا لم يُدخَل وصف. (وصف الدرس مصدره `summary`.)

## الأخطاء
| الرمز | المعنى |
|------|--------|
| `401` | توكن مفقود/غير صالح/منتهٍ |
| `403` | الجلسة صالحة لكن الدور ليس `student` |
| `404` | المادة غير موجودة/غير منشورة؛ أو درس غير منشور أو `can_open=false` |

## مرجع أنواع الحقول (لنماذج Dart)
| الحقل | النوع | null؟ |
|------|------|------|
| `subjects[].id` | int | لا |
| `subjects[].title` | String (إنجليزي) | لا |
| `subjects[].description` | String? | نعم |
| `subjects[].thumbnail_url` | String? | **نعم (دائمًا null)** |
| `subjects[].topics_count` | int | لا |
| `subjects[].lessons_count` | int | لا |
| `subjects[].available_lessons_count` | int | لا |
| `outline.id` / `outline.title` / `outline.description` | int / String / String? | — / لا / نعم |
| `topics[].id` / `title` / `description` / `display_order` | int / String / String? / int | — |
| `topics[].lessons_count` | int | لا |
| `topics[].available_lessons_count` | int | لا |
| `topics[].completed_lessons` | int | لا |
| `topics[].progress_percentage` | double (0–100) | لا |
| `lessons[].id` / `title` / `description` / `display_order` | int / String / String? / int | — |
| `lessons[].status` | String (`not_started`/`in_progress`/`completed`) | لا |
| `lessons[].can_open` | bool | لا |
| `lessons[].is_available` | bool | لا |
| `lessons[].thumbnail_url` | String? | **نعم (دائمًا null)** |
| `lesson.id` / `title` / `description` | int / String / String? | — / لا / نعم |
| `lesson.can_open` | bool | لا |
| `lesson.is_available` | bool | لا |
| `lesson.status` | String (`not_started`/`in_progress`/`completed`) | لا |
| `lesson.sections[].key` / `display_order` | String / int | لا |
| `sections[].blocks[].block_type` | String (`text`/`image`/`video`/`model_3d`) | لا |
| `sections[].blocks[].title` / `text` / `resource_url` / `alternative_text` | String? | نعم |

## قيود/افتراضات (مستوى النشر)
- لا عمود `status` للمواد/المواضيع؛ النشر على مستوى الدرس فقط
  (`lessons.status`). المادة/الموضوع "منشور" متى احتوى درسًا منشورًا.
- لا `display_order` للمواد ⇒ ترتيبها بالـ`id`.
- **`can_open`** (قابل للفتح) = درس منشور **وله محتوى** (بلوكات). يُشغّل الزر
  ويسمح بجلب الدرس.
- **`is_available`** (جاهز للدراسة) = درس منشور و `lessons.is_content_ready = TRUE`
  (**قرار صريح**، مستقلّ عن المحتوى). إضافة Overview تجعل الدرس `can_open`
  لكن **لا** تجعله `is_available`؛ يبقى غير جاهز حتى يُضبط العلم صراحةً.

> ⚠️ **قاعدة مؤقتة:** `is_content_ready` حاليًا قرار يدوي بأن الدرس جاهز،
> **وليس** تحقّقًا آليًا من اكتمال المحتوى. قد يُستبدَل لاحقًا بمعيار أدقّ.

### تسجيل إكمال الدرس
لا يوجد حاليًا مسار لتسجيل إكمال الدرس. **عند إضافته لاحقًا**، يجب منع تعليم
الدرس `completed` طالما `is_content_ready = FALSE` (لا يُكمَل درس غير جاهز حتى
لو كان `can_open`).

## الاتّساق مع Profile Overview
نفس قاعدة الإتاحة مطبّقة في `GET /students/me/profile-overview`: الدروس
Coming soon **لا تُختار** في `continue_learning`، ولا تُحتسب في
`overall_progress_percentage` ولا في تقدّم الوحدة داخل بطاقة المتابعة. فإن لم
يوجد درس متاح غير مكتمل ⇒ `continue_learning = null` والتقدّم صفر.

## Migration
هذا التسليم يضيف عمودين (migration `sql/003_lesson_content_ready_and_sections.sql`):
`lessons.is_content_ready` (BOOLEAN، افتراضيًا FALSE) و`lesson_blocks.section`
(VARCHAR). قابل لإعادة التشغيل (`IF NOT EXISTS`). طُبِّق على قاعدتي التطوير
والاختبار. تشغيله يدويًا: `psql -d "<db>" -f sql/003_lesson_content_ready_and_sections.sql`.

## تجربة من Swagger (بحسابك)
1. شغّلي الباك: `.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8001`
2. (مرة واحدة) ازرعي المحتوى: `.\.venv\Scripts\python.exe scripts\seed_learn_content.py`
   ثم محتوى Overview: `.\.venv\Scripts\python.exe scripts\seed_lesson_overview.py`
3. افتحي `http://127.0.0.1:8001/docs`.
4. `POST /auth/login` ببريد وكلمة مرور طالب ⇒ انسخي `access_token`.
5. اضغطي **Authorize** وألصقي التوكن (بدون كلمة `Bearer`؛ Swagger يضيفها).
6. نفّذي `GET /learning/subjects`، خذي `id` المادة من الاستجابة (**لا تفترضي
   `1`**)، ثم `GET /learning/subjects/{id}/outline`.
7. `GET /learning/lessons/13` (Heart Chambers) تُعيد **200** مع قسم Overview
   (`can_open=true`, `is_available=false`). بينما `GET /learning/lessons/14`
   تُعيد **404** (لا محتوى بعد، `can_open=false`).

> المعرّفات الفعلية في قاعدة التطوير: المادة `id=3`، الوحدة `id=3`، الدروس
> `13, 14, 15`. **Heart Chambers (`id=13`)**: `can_open=true` (له Overview)،
> `is_available=false` (غير جاهز بعد). الدرسان `14, 15`: `can_open=false`
> ("Coming soon"). لا درس `is_available=true` بعد ⇒ `available_lessons_count=0`.
