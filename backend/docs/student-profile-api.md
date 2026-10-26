# Student Profile API

مسارات الملف الطلابي للمستخدم الحالي. كلاهما يتطلب جلسة صالحة
لمستخدم دوره `student`.

- `GET /students/me` — قراءة الملف الطلابي الحالي.
- `PATCH /students/me` — تعديل جزئي للملف الطلابي.

## المصادقة (Bearer token)

كل الطلبات تحتاج ترويسة `Authorization` تحمل التوكن الذي يعيده
`POST /auth/login` في الحقل `access_token`:

```
Authorization: Bearer <access_token>
```

`user_id` يُؤخذ من الجلسة دائمًا؛ لا يُرسله العميل ولا يُقبل من جسم الطلب.
جميع الاستجابات تتضمن `Cache-Control: no-store`.

> التوكنات أدناه أمثلة فقط، وليست قيمًا حقيقية.

## الحقول

| الحقل | المصدر | النوع | ملاحظات |
|------|--------|------|---------|
| `id` | `users.id` | integer | معرّف المستخدم، للقراءة فقط |
| `full_name` | `users.full_name` | string | 1–150 بعد إزالة الفراغات |
| `email` | `users.email` | string | للقراءة فقط، لا يُعدَّل هنا |
| `university` | `student_profiles.university` | string \| null | بحد أقصى 200 |
| `study_year` | `student_profiles.study_year` | integer \| null | من 1 إلى 6 |
| `preferred_language` | `student_profiles.preferred_language` | `"ar"` \| `"en"` | إلزامي، لا يقبل null |

## GET /students/me

يعيد `200` بالملف الطلابي الكامل.

مثال الطلب:

```
GET /students/me
Authorization: Bearer EXAMPLE_TOKEN
```

مثال الرد (`200`):

```json
{
  "id": 2,
  "full_name": "Wala Student",
  "email": "wala.student@example.com",
  "university": "An-Najah National University",
  "study_year": 4,
  "preferred_language": "ar"
}
```

- `university` و`study_year` قد يكونان `null`.
- إذا لم يوجد ملف طلابي للمستخدم، يعيد `404`. لا يُنشئ GET أي ملف.

## PATCH /students/me

تعديل جزئي: أرسل الحقول التي تريد تغييرها فقط.

الحقول المسموحة فقط: `full_name`, `university`, `study_year`,
`preferred_language`. أي حقل آخر (مثل `id`, `user_id`, `email`, `role`,
`password`, أو أي `progress`) يُرفض بـ `422`.

### دلالة الإرسال

| الحالة في الطلب | الأثر |
|-----------------|------|
| الحقل غير مرسل | يبقى كما هو دون تغيير |
| `university` = `null` أو `""` | يُمسح (يصبح `null`) |
| `study_year` = `null` | يُمسح (يصبح `null`) |
| `full_name` = `null` أو `""` | مرفوض بـ `422` |
| `preferred_language` = `null` | مرفوض بـ `422` |

قواعد التحقق:

- `full_name`: تُزال الفراغات من الطرفين ثم يجب أن يكون الطول 1–150.
- `university`: تُزال الفراغات؛ الفارغ/`null` يعني المسح؛ الحد الأقصى 200.
- `study_year`: عدد صحيح 1–6، أو `null` للمسح. يُرفض boolean والأعداد الكسرية.
- `preferred_language`: `"ar"` أو `"en"` فقط.
- الطلب الفارغ `{}` مرفوض بـ `422`.

يُحدَّث `full_name` في جدول `users`، وبقية الحقول في `student_profiles`،
ضمن معاملة واحدة تتراجع بالكامل عند الفشل. يعيد `200` بالملف الكامل
بعد التحديث (نفس نموذج GET).

مثال الطلب:

```
PATCH /students/me
Authorization: Bearer EXAMPLE_TOKEN
Content-Type: application/json

{
  "full_name": "Wala Student",
  "study_year": 5,
  "university": null
}
```

مثال الرد (`200`):

```json
{
  "id": 2,
  "full_name": "Wala Student",
  "email": "wala.student@example.com",
  "university": null,
  "study_year": 5,
  "preferred_language": "ar"
}
```

## الأخطاء

| الرمز | المعنى | مثال التفاصيل |
|------|--------|----------------|
| `401` | توكن مفقود أو غير صالح أو منتهٍ | `Invalid or expired session. Please log in.` |
| `403` | الجلسة صالحة لكن الدور ليس `student` | `Only students can access the student profile.` |
| `404` | لا يوجد ملف طلابي للمستخدم | `Student profile not found.` |
| `422` | فشل التحقق (حقل ممنوع، نوع خاطئ، قيمة خارج النطاق، طلب فارغ) | قائمة أخطاء في `detail` |

بنية خطأ `422` تتبع المعالج الحالي في المشروع: جسم فيه `detail`
كقائمة عناصر `{loc, msg, type}`، دون إعادة قيم المدخلات المرسلة.

مثال خطأ `403`:

```json
{ "detail": "Only students can access the student profile." }
```

مثال خطأ `422` (حقل ممنوع):

```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "Extra inputs are not permitted",
      "type": "extra_forbidden"
    }
  ]
}
```
