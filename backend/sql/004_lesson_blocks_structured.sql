-- Med Companion — migration 004
-- يدعم بلوكات محتوى منظّمة (بطاقات الحجرات، المقارنة، نشاط Think→Reveal،
-- مسرد المصطلحات) دون إنشاء منظومة تعليمية جديدة.
--
-- لماذا:
--   - block_key: مفتاح ثابت لكل بلوك (مثل 'core_right_atrium') لتمييزه عند
--     الإدخال/التحديث بدل الاعتماد على العنوان الإنجليزي.
--   - content_type: نوع العرض المنطقي للبلوك ('intro'/'chamber'/'comparison'/
--     'think_reveal'/'glossary'/'text'). يبقى block_type='text' كما يفرض
--     قيد lesson_blocks الحالي؛ لا نغيّر ذلك القيد.
--   - data (JSONB): الحمولة المنظّمة (segments المرتبطة بالمصطلحات، اختصار
--     الحجرة ونقطتها المفتاحية و structure_key، أعمدة/صفوف المقارنة، نصّ
--     Think→Reveal، تعريفات المسرد). text_content يبقى النص الكامل للتوافق.
--
-- فهرس فريد جزئي على (lesson_id, block_key) لدعم التحديث الثابت (upsert).
-- المصادر تُخزَّن في source_documents + lesson_sources الموجودين (لا جداول جديدة).
--
-- آمن وقابل لإعادة التشغيل (IF NOT EXISTS). لا يحذف ولا يعدّل بيانات قائمة،
-- ولا يغيّر قيود block_type/المحتوى.
-- التشغيل: psql -d "<db>" -f sql/004_lesson_blocks_structured.sql

BEGIN;

ALTER TABLE public.lesson_blocks
    ADD COLUMN IF NOT EXISTS block_key VARCHAR(60);

ALTER TABLE public.lesson_blocks
    ADD COLUMN IF NOT EXISTS content_type VARCHAR(30);

ALTER TABLE public.lesson_blocks
    ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS lesson_blocks_lesson_key_idx
    ON public.lesson_blocks (lesson_id, block_key)
    WHERE block_key IS NOT NULL;

COMMIT;
