# Learn API — تسليم أول واجهتين (لنادية / الفرونت إند)

مساران يغذّيان أول شاشتين من قسم Learn:

- `GET /learning/subjects` — شاشة Learn Home (قائمة المواد).
- `GET /learning/subjects/{subject_id}/outline` — شاشة Subject Outline
  (المواضيع ودروسها وحالة كل درس للطالب).

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

## نموذج "Coming soon" (إتاحة المحتوى منفصلة عن تقدّم الطالب)

لكل درس بُعدان مستقلّان تمامًا:

1. **`is_available`** — هل محتوى الدرس جاهز للدراسة؟
   - `true` = الدرس منشور وله محتوى → افتحيه عند الضغط.
   - `false` = **"Coming soon"** → اعرضي العنوان، ضعي شارة "Coming soon"،
     و**عطّلي زر الدخول** (لا تفتحي صفحة الدرس).
2. **`status`** — تقدّم هذا الطالب في الدرس فقط: `not_started` / `in_progress`
   / `completed`. مستقلّ عن `is_available`.

العدّادات تفرّق بين:
- **المعروض** (`lessons_count`): كل الدروس المنشورة في القائمة (شامل Coming soon).
- **المتاح للدراسة** (`available_lessons_count`): الدروس الجاهزة فقط. وهو **مقام
  نسبة التقدّم**.

> حاليًا الدروس المزروعة عناوين فقط بلا محتوى، فكلها `is_available=false`
> ("Coming soon") حتى يُضاف محتواها لاحقًا.

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
      "available_lessons_count": 1,
      "completed_lessons": 1,
      "progress_percentage": 100.0,
      "lessons": [
        {
          "id": 1,
          "title": "Heart Chambers",
          "description": "Identify the four chambers and understand their basic roles.",
          "display_order": 1,
          "status": "completed",
          "is_available": true,
          "thumbnail_url": null
        },
        {
          "id": 2,
          "title": "Heart Valves & Great Vessels",
          "description": "Explore heart valves and the major vessels connected to the heart.",
          "display_order": 2,
          "status": "not_started",
          "is_available": false,
          "thumbnail_url": null
        },
        {
          "id": 3,
          "title": "Blood Flow Through the Heart",
          "description": "Trace the path of blood through the heart.",
          "display_order": 3,
          "status": "not_started",
          "is_available": false,
          "thumbnail_url": null
        }
      ]
    }
  ]
}
```

### سلوك زر الدرس (مهم)
| `is_available` | العرض | الزر |
|----------------|-------|------|
| `true` | عنوان + حالة التقدّم (`status`) | مُفعّل → يفتح الدرس |
| `false` | عنوان + شارة **"Coming soon"** | **مُعطّل** → لا يفتح شيئًا |

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

## الحقول التي تكون null حاليًا
- `thumbnail_url` (للمادة وللدرس): غير مخزَّن في المخطط ⇒ **null دائمًا**.
  استخدمي صورة/أيقونة بديلة.
- `description`: قد يكون `null` إذا لم يُدخَل وصف. (وصف الدرس مصدره `summary`.)

## الأخطاء
| الرمز | المعنى |
|------|--------|
| `401` | توكن مفقود/غير صالح/منتهٍ |
| `403` | الجلسة صالحة لكن الدور ليس `student` |
| `404` | المادة غير موجودة، أو غير منشورة (لا تحوي أي درس منشور) |

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
| `lessons[].is_available` | bool | لا |
| `lessons[].thumbnail_url` | String? | **نعم (دائمًا null)** |

## قيود/افتراضات (مستوى النشر)
- لا عمود `status` للمواد/المواضيع؛ النشر على مستوى الدرس فقط
  (`lessons.status`). المادة/الموضوع "منشور" متى احتوى درسًا منشورًا.
- لا `display_order` للمواد ⇒ ترتيبها بالـ`id`.
- "متاح للدراسة" = درس منشور وله **بلوك محتوى واحد على الأقل** (`lesson_blocks`).
  الدرس المنشور بلا محتوى = "Coming soon".

> ⚠️ **قاعدة مؤقتة:** «بلوك واحد = متاح» هي إشارة بسيطة لوجود محتوى، وليست
> تحقّقًا من اكتمال/جاهزية محتوى الدرس (لا تتحقّق من اكتمال الأقسام أو مراجعة
> المحتوى). هي كافية لتمييز "عنوان فقط" من "فيه محتوى" في هذه المرحلة، وقد
> تُستبدَل لاحقًا بمعيار جاهزية أدقّ.

## الاتّساق مع Profile Overview
نفس قاعدة الإتاحة مطبّقة في `GET /students/me/profile-overview`: الدروس
Coming soon **لا تُختار** في `continue_learning`، ولا تُحتسب في
`overall_progress_percentage` ولا في تقدّم الوحدة داخل بطاقة المتابعة. فإن لم
يوجد درس متاح غير مكتمل ⇒ `continue_learning = null` والتقدّم صفر.

## تجربة من Swagger (بحسابك)
1. شغّلي الباك: `.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8001`
2. (مرة واحدة) ازرعي المحتوى: `.\.venv\Scripts\python.exe scripts\seed_learn_content.py`
3. افتحي `http://127.0.0.1:8001/docs`.
4. `POST /auth/login` ببريد وكلمة مرور طالب ⇒ انسخي `access_token`.
5. اضغطي **Authorize** وألصقي التوكن (بدون كلمة `Bearer`؛ Swagger يضيفها).
6. نفّذي `GET /learning/subjects`، خذي `id` المادة من الاستجابة (**لا تفترضي
   `1`؛ في قاعدة التطوير الحالية هو `3`**)، ثم نفّذي
   `GET /learning/subjects/{id}/outline`.

> المعرّفات الفعلية حاليًا في قاعدة التطوير: المادة `id=3`، الوحدة `id=3`،
> الدروس `13, 14, 15` — وكلها Coming soon (`available_lessons_count=0`) حتى
> يُضاف محتواها.
