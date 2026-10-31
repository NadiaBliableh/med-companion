-- Med Companion — migration 003
-- يفصل "جاهزية محتوى الدرس" عن مجرّد وجود بلوكات، ويضيف مفتاح قسم للبلوكات.
--
-- لماذا:
--   - سابقًا كان الدرس يُعتبر "متاحًا للدراسة" بمجرّد وجود صف في lesson_blocks.
--     هذا ليس قرار جاهزية؛ إضافة قسم Overview وحده كانت تجعل الدرس متاحًا.
--   - is_content_ready: قرار صريح (افتراضيًا FALSE) بأن محتوى الدرس جاهز
--     للدراسة. الدرس يبقى يظهر في القائمة كـ "Coming soon" حتى يُضبط TRUE.
--   - lesson_blocks.section: مفتاح القسم (مثل 'overview') لتجميع البلوكات
--     المرتبة ضمن أقسام الدرس.
--
-- آمن وقابل لإعادة التشغيل (IF NOT EXISTS). لا يحذف ولا يعدّل أي بيانات قائمة.
-- التشغيل على قاعدة التطوير وقاعدة الاختبار، مثلًا:
--   psql -d "<db>" -f sql/003_lesson_content_ready_and_sections.sql
-- أو عبر psycopg: اقرأ الملف ونفّذه داخل اتصال واحد (انظر docs/learn-api.md).

BEGIN;

ALTER TABLE public.lessons
    ADD COLUMN IF NOT EXISTS is_content_ready BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.lesson_blocks
    ADD COLUMN IF NOT EXISTS section VARCHAR(40);

COMMIT;
