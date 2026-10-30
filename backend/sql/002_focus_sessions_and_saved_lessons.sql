-- 002_focus_sessions_and_saved_lessons.sql
--
-- توثيق جدولَي focus_sessions و saved_lessons اللذين أُضيفا يدويًا على
-- قاعدة البيانات الحيّة ولم يكونا في 000_med_companion_full_schema.sql.
-- هذا الملف مُعاد بناؤه من استكشاف القاعدة الحيّة (أعمدة/قيود/فهارس)،
-- والهدف منه تهيئة قاعدة اختبار أو قاعدة جديدة مطابقة. كلها IF NOT EXISTS
-- فلا تُعدّل الجداول الموجودة على القاعدة الحيّة.
--
-- ملاحظة: قبل الاعتماد عليه لقاعدة إنتاج جديدة، قارنه بالـDDL الفعلي
-- للقاعدة الحيّة (pg_dump) للتأكد من تطابق أطوال VARCHAR والقيود بدقّة.

CREATE TABLE IF NOT EXISTS public.focus_sessions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id BIGINT NOT NULL,
    lesson_id BIGINT,
    goal_text TEXT CHECK (goal_text IS NULL OR LENGTH(TRIM(goal_text)) > 0),
    phase VARCHAR(10) NOT NULL DEFAULT 'study'
        CHECK (phase IN ('study','break')),
    planned_seconds INTEGER NOT NULL CHECK (planned_seconds > 0),
    status VARCHAR(10) NOT NULL DEFAULT 'running'
        CHECK (status IN ('running','paused','completed','cancelled')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active_started_at TIMESTAMPTZ,
    accumulated_active_seconds INTEGER NOT NULL DEFAULT 0
        CHECK (accumulated_active_seconds >= 0),
    ended_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    FOREIGN KEY (student_id)
        REFERENCES public.student_profiles (user_id) ON DELETE RESTRICT,
    FOREIGN KEY (lesson_id)
        REFERENCES public.lessons (id) ON DELETE RESTRICT,
    CHECK (
        (status IN ('completed','cancelled') AND ended_at IS NOT NULL)
        OR (status IN ('running','paused') AND ended_at IS NULL)
    ),
    CHECK (ended_at IS NULL OR ended_at >= started_at),
    CHECK (active_started_at IS NULL OR active_started_at >= started_at)
);

-- جلسة نشطة واحدة (running/paused) لكل طالب.
CREATE UNIQUE INDEX IF NOT EXISTS focus_sessions_one_active_per_student
    ON public.focus_sessions (student_id)
    WHERE status IN ('running','paused');

CREATE INDEX IF NOT EXISTS focus_sessions_student_started_idx
    ON public.focus_sessions (student_id, started_at);

CREATE INDEX IF NOT EXISTS focus_sessions_lesson_idx
    ON public.focus_sessions (lesson_id);


CREATE TABLE IF NOT EXISTS public.saved_lessons (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id BIGINT NOT NULL,
    lesson_id BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id)
        REFERENCES public.student_profiles (user_id) ON DELETE RESTRICT,
    FOREIGN KEY (lesson_id)
        REFERENCES public.lessons (id) ON DELETE RESTRICT,
    UNIQUE (student_id, lesson_id)
);
