-- Med Companion: complete initial schema (27 tables), PostgreSQL 16
-- For a NEW EMPTY database only. Not a migration or a live database export.
-- In pgAdmin first create med_companion, then open its Query Tool and run this file.
-- Includes auth_sessions: DO NOT also run 001_create_auth_sessions.sql.
-- No users, passwords, tokens, clinical content or sample data are included.
-- Failure: inspect the FIRST error, then run ROLLBACK before retrying.
-- Most constraints use PostgreSQL-generated names; these may differ from Wala's DB.

BEGIN;

-- 1. users
CREATE TABLE public.users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL CHECK (LENGTH(TRIM(full_name)) > 0),
    email VARCHAR(254) NOT NULL CHECK (LENGTH(TRIM(email)) > 0),
    password_hash TEXT NOT NULL CHECK (LENGTH(TRIM(password_hash)) > 0),
    role VARCHAR(20) NOT NULL DEFAULT 'student' CHECK (role IN ('student','admin','reviewer')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. student_profiles
CREATE TABLE public.student_profiles (
    user_id BIGINT PRIMARY KEY,
    university VARCHAR(200),
    study_year SMALLINT CHECK (study_year BETWEEN 1 AND 6),
    preferred_language VARCHAR(5) NOT NULL DEFAULT 'ar' CHECK (preferred_language IN ('ar','en')),
    FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE RESTRICT
);

-- 3. subjects
CREATE TABLE public.subjects (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name_ar VARCHAR(150) NOT NULL CHECK (LENGTH(TRIM(name_ar)) > 0),
    name_en VARCHAR(150) NOT NULL CHECK (LENGTH(TRIM(name_en)) > 0),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. topics
CREATE TABLE public.topics (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subject_id BIGINT NOT NULL,
    name_ar VARCHAR(150) NOT NULL CHECK (LENGTH(TRIM(name_ar)) > 0),
    name_en VARCHAR(150) NOT NULL CHECK (LENGTH(TRIM(name_en)) > 0),
    description TEXT,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    FOREIGN KEY (subject_id) REFERENCES public.subjects (id) ON DELETE RESTRICT
);

-- 5. lessons
CREATE TABLE public.lessons (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    topic_id BIGINT NOT NULL,
    title_ar VARCHAR(200) NOT NULL CHECK (LENGTH(TRIM(title_ar)) > 0),
    title_en VARCHAR(200) NOT NULL CHECK (LENGTH(TRIM(title_en)) > 0),
    summary TEXT,
    suggested_year SMALLINT CHECK (suggested_year BETWEEN 1 AND 6),
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (topic_id) REFERENCES public.topics (id) ON DELETE RESTRICT
);

-- 6. lesson_blocks
CREATE TABLE public.lesson_blocks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lesson_id BIGINT NOT NULL,
    block_type VARCHAR(20) NOT NULL CHECK (block_type IN ('text','image','video','model_3d')),
    title VARCHAR(200),
    text_content TEXT,
    resource_url TEXT,
    alternative_text TEXT,
    display_order INTEGER NOT NULL CHECK (display_order >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES public.lessons (id) ON DELETE RESTRICT,
    UNIQUE (lesson_id, display_order),
    CHECK ((block_type = 'text' AND NULLIF(TRIM(text_content), '') IS NOT NULL) OR (block_type IN ('image','video','model_3d') AND NULLIF(TRIM(resource_url), '') IS NOT NULL))
);

-- 7. lesson_progress
CREATE TABLE public.lesson_progress (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id BIGINT NOT NULL,
    lesson_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','completed')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    FOREIGN KEY (student_id) REFERENCES public.student_profiles (user_id) ON DELETE RESTRICT,
    FOREIGN KEY (lesson_id) REFERENCES public.lessons (id) ON DELETE RESTRICT,
    UNIQUE (student_id, lesson_id),
    CHECK ((status = 'in_progress' AND completed_at IS NULL) OR (status = 'completed' AND completed_at IS NOT NULL)),
    CHECK (last_accessed_at >= started_at),
    CHECK (completed_at IS NULL OR completed_at >= started_at)
);

-- 8. source_documents
CREATE TABLE public.source_documents (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL CHECK (LENGTH(TRIM(title)) > 0),
    source_type VARCHAR(20) NOT NULL CHECK (source_type IN ('book','article','guideline','website','other')),
    authors TEXT,
    publisher TEXT,
    publication_year SMALLINT CHECK (publication_year > 0),
    edition VARCHAR(100),
    doi TEXT,
    source_url TEXT,
    file_path TEXT,
    license_notes TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 9. lesson_sources
CREATE TABLE public.lesson_sources (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lesson_id BIGINT NOT NULL,
    source_document_id BIGINT NOT NULL,
    page_reference TEXT,
    chapter_reference TEXT,
    evidence_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lesson_id) REFERENCES public.lessons (id) ON DELETE RESTRICT,
    FOREIGN KEY (source_document_id) REFERENCES public.source_documents (id) ON DELETE RESTRICT,
    UNIQUE (lesson_id, source_document_id)
);

-- 10. questions
CREATE TABLE public.questions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    topic_id BIGINT NOT NULL,
    question_text TEXT NOT NULL CHECK (LENGTH(TRIM(question_text)) > 0),
    explanation TEXT NOT NULL CHECK (LENGTH(TRIM(explanation)) > 0),
    language VARCHAR(5) NOT NULL DEFAULT 'ar' CHECK (language IN ('ar','en')),
    difficulty VARCHAR(10) NOT NULL DEFAULT 'medium' CHECK (difficulty IN ('easy','medium','hard')),
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
    source_document_id BIGINT,
    page_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (topic_id) REFERENCES public.topics (id) ON DELETE RESTRICT,
    FOREIGN KEY (source_document_id) REFERENCES public.source_documents (id) ON DELETE RESTRICT
);

-- 11. question_options
CREATE TABLE public.question_options (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    question_id BIGINT NOT NULL,
    option_text TEXT NOT NULL CHECK (LENGTH(TRIM(option_text)) > 0),
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    display_order SMALLINT NOT NULL CHECK (display_order >= 1),
    FOREIGN KEY (question_id) REFERENCES public.questions (id) ON DELETE RESTRICT,
    UNIQUE (question_id, display_order),
    UNIQUE (question_id, id)
);

-- 12. quiz_attempts
CREATE TABLE public.quiz_attempts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','submitted','abandoned')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMPTZ,
    FOREIGN KEY (student_id) REFERENCES public.student_profiles (user_id) ON DELETE RESTRICT,
    CHECK ((status = 'submitted' AND submitted_at IS NOT NULL) OR (status IN ('in_progress','abandoned') AND submitted_at IS NULL)),
    CHECK (submitted_at IS NULL OR submitted_at >= started_at)
);

-- 13. quiz_attempt_items
CREATE TABLE public.quiz_attempt_items (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    attempt_id BIGINT NOT NULL,
    question_id BIGINT NOT NULL,
    display_order INTEGER NOT NULL CHECK (display_order >= 1),
    selected_option_id BIGINT,
    answered_at TIMESTAMPTZ,
    max_score NUMERIC(6,2) NOT NULL DEFAULT 1 CHECK (max_score > 0),
    awarded_score NUMERIC(6,2) CHECK (awarded_score IS NULL OR (awarded_score >= 0 AND awarded_score <= max_score)),
    FOREIGN KEY (attempt_id) REFERENCES public.quiz_attempts (id) ON DELETE RESTRICT,
    FOREIGN KEY (question_id) REFERENCES public.questions (id) ON DELETE RESTRICT,
    FOREIGN KEY (question_id, selected_option_id) REFERENCES public.question_options (question_id, id) ON DELETE RESTRICT,
    UNIQUE (attempt_id, question_id),
    UNIQUE (attempt_id, display_order),
    CHECK ((selected_option_id IS NULL AND answered_at IS NULL) OR (selected_option_id IS NOT NULL AND answered_at IS NOT NULL))
);

-- 14. clinical_cases
CREATE TABLE public.clinical_cases (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(200) NOT NULL CHECK (LENGTH(TRIM(title)) > 0),
    specialty VARCHAR(100) NOT NULL CHECK (LENGTH(TRIM(specialty)) > 0),
    difficulty VARCHAR(10) NOT NULL DEFAULT 'medium' CHECK (difficulty IN ('easy','medium','hard')),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 15. case_versions
CREATE TABLE public.case_versions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_id BIGINT NOT NULL,
    version_number INTEGER NOT NULL CHECK (version_number >= 1),
    language VARCHAR(5) NOT NULL DEFAULT 'ar' CHECK (language IN ('ar','en')),
    student_instructions TEXT NOT NULL CHECK (LENGTH(TRIM(student_instructions)) > 0),
    time_limit_minutes SMALLINT CHECK (time_limit_minutes > 0),
    patient_name VARCHAR(150) NOT NULL CHECK (LENGTH(TRIM(patient_name)) > 0),
    patient_age SMALLINT NOT NULL CHECK (patient_age BETWEEN 0 AND 120),
    patient_sex VARCHAR(20) NOT NULL CHECK (patient_sex IN ('male','female','other','unknown')),
    chief_complaint TEXT NOT NULL CHECK (LENGTH(TRIM(chief_complaint)) > 0),
    expected_diagnosis TEXT NOT NULL CHECK (LENGTH(TRIM(expected_diagnosis)) > 0),
    avatar_model_path TEXT,
    avatar_settings JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(avatar_settings) = 'object'),
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
    reviewed_by BIGINT,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (case_id) REFERENCES public.clinical_cases (id) ON DELETE RESTRICT,
    FOREIGN KEY (reviewed_by) REFERENCES public.users (id) ON DELETE RESTRICT,
    UNIQUE (case_id, version_number),
    CHECK ((reviewed_by IS NULL AND reviewed_at IS NULL) OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)),
    CHECK (status <> 'published' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);

-- 16. case_facts
CREATE TABLE public.case_facts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_version_id BIGINT NOT NULL,
    category VARCHAR(40) NOT NULL CHECK (category IN ('presenting_history','associated_symptoms','medical_history','surgical_history','medications','allergies','family_history','social_history','other')),
    fact_key VARCHAR(100) NOT NULL CHECK (LENGTH(TRIM(fact_key)) > 0),
    fact_value TEXT NOT NULL CHECK (LENGTH(TRIM(fact_value)) > 0),
    patient_answer TEXT CHECK (patient_answer IS NULL OR LENGTH(TRIM(patient_answer)) > 0),
    FOREIGN KEY (case_version_id) REFERENCES public.case_versions (id) ON DELETE RESTRICT,
    UNIQUE (case_version_id, fact_key)
);

-- 17. case_findings
CREATE TABLE public.case_findings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_version_id BIGINT NOT NULL,
    finding_key VARCHAR(100) NOT NULL CHECK (LENGTH(TRIM(finding_key)) > 0),
    finding_type VARCHAR(30) NOT NULL CHECK (finding_type IN ('vital_sign','physical_exam','laboratory','imaging','procedure','other')),
    finding_name VARCHAR(200) NOT NULL CHECK (LENGTH(TRIM(finding_name)) > 0),
    result_text TEXT NOT NULL CHECK (LENGTH(TRIM(result_text)) > 0),
    unit VARCHAR(50),
    reference_range TEXT,
    resource_url TEXT,
    availability VARCHAR(20) NOT NULL DEFAULT 'on_request' CHECK (availability IN ('initial','on_request')),
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    FOREIGN KEY (case_version_id) REFERENCES public.case_versions (id) ON DELETE RESTRICT,
    UNIQUE (case_version_id, finding_key),
    UNIQUE (case_version_id, id)
);

-- 18. case_sources
CREATE TABLE public.case_sources (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_version_id BIGINT NOT NULL,
    source_document_id BIGINT NOT NULL,
    page_reference TEXT,
    chapter_reference TEXT,
    evidence_note TEXT NOT NULL CHECK (LENGTH(TRIM(evidence_note)) > 0),
    FOREIGN KEY (case_version_id) REFERENCES public.case_versions (id) ON DELETE RESTRICT,
    FOREIGN KEY (source_document_id) REFERENCES public.source_documents (id) ON DELETE RESTRICT,
    UNIQUE (case_version_id, source_document_id)
);

-- 19. rubric_items
CREATE TABLE public.rubric_items (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_version_id BIGINT NOT NULL,
    criterion_key VARCHAR(100) NOT NULL CHECK (LENGTH(TRIM(criterion_key)) > 0),
    section VARCHAR(30) NOT NULL CHECK (section IN ('history','communication','physical_exam','investigations','clinical_reasoning','safety','other')),
    criterion_text TEXT NOT NULL CHECK (LENGTH(TRIM(criterion_text)) > 0),
    scoring_guidance TEXT NOT NULL CHECK (LENGTH(TRIM(scoring_guidance)) > 0),
    max_score NUMERIC(6,2) NOT NULL DEFAULT 1 CHECK (max_score > 0),
    is_critical BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0 CHECK (display_order >= 0),
    FOREIGN KEY (case_version_id) REFERENCES public.case_versions (id) ON DELETE RESTRICT,
    UNIQUE (case_version_id, criterion_key),
    UNIQUE (case_version_id, id)
);

-- 20. osce_sessions
CREATE TABLE public.osce_sessions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id BIGINT NOT NULL,
    case_version_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','completed','abandoned')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMPTZ,
    proposed_diagnosis TEXT,
    differential_diagnosis TEXT,
    diagnostic_reasoning TEXT,
    FOREIGN KEY (student_id) REFERENCES public.student_profiles (user_id) ON DELETE RESTRICT,
    FOREIGN KEY (case_version_id) REFERENCES public.case_versions (id) ON DELETE RESTRICT,
    CHECK ((status = 'in_progress' AND ended_at IS NULL) OR (status IN ('completed','abandoned') AND ended_at IS NOT NULL)),
    CHECK (ended_at IS NULL OR ended_at >= started_at),
    UNIQUE (id, case_version_id)
);

-- 21. session_messages
CREATE TABLE public.session_messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id BIGINT NOT NULL,
    speaker VARCHAR(20) NOT NULL CHECK (speaker IN ('student','patient')),
    message_text TEXT NOT NULL CHECK (LENGTH(TRIM(message_text)) > 0),
    input_method VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (input_method IN ('text','speech')),
    sequence_number INTEGER NOT NULL CHECK (sequence_number >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES public.osce_sessions (id) ON DELETE RESTRICT,
    UNIQUE (session_id, sequence_number),
    UNIQUE (session_id, id)
);

-- 22. session_actions
CREATE TABLE public.session_actions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id BIGINT NOT NULL,
    case_version_id BIGINT NOT NULL,
    action_type VARCHAR(30) NOT NULL CHECK (action_type IN ('finding_requested','finding_viewed','note_added')),
    finding_id BIGINT,
    action_details JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(action_details) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id, case_version_id) REFERENCES public.osce_sessions (id, case_version_id) ON DELETE RESTRICT,
    FOREIGN KEY (case_version_id, finding_id) REFERENCES public.case_findings (case_version_id, id) ON DELETE RESTRICT,
    CHECK ((action_type IN ('finding_requested','finding_viewed') AND finding_id IS NOT NULL) OR (action_type = 'note_added' AND finding_id IS NULL)),
    UNIQUE (session_id, id)
);

-- 23. session_evaluations
CREATE TABLE public.session_evaluations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id BIGINT NOT NULL UNIQUE,
    case_version_id BIGINT NOT NULL,
    evaluation_method VARCHAR(20) NOT NULL CHECK (evaluation_method IN ('rules','ai','hybrid')),
    evaluator_version VARCHAR(100) NOT NULL CHECK (LENGTH(TRIM(evaluator_version)) > 0),
    model_name VARCHAR(150) CHECK (model_name IS NULL OR LENGTH(TRIM(model_name)) > 0),
    overall_feedback TEXT NOT NULL CHECK (LENGTH(TRIM(overall_feedback)) > 0),
    strengths TEXT,
    areas_for_improvement TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id, case_version_id) REFERENCES public.osce_sessions (id, case_version_id) ON DELETE RESTRICT,
    CHECK (evaluation_method = 'rules' OR model_name IS NOT NULL),
    UNIQUE (id, session_id, case_version_id)
);

-- 24. evaluation_items
CREATE TABLE public.evaluation_items (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    evaluation_id BIGINT NOT NULL,
    session_id BIGINT NOT NULL,
    case_version_id BIGINT NOT NULL,
    rubric_item_id BIGINT NOT NULL,
    max_score NUMERIC(6,2) NOT NULL CHECK (max_score > 0),
    awarded_score NUMERIC(6,2) NOT NULL CHECK (awarded_score >= 0 AND awarded_score <= max_score),
    rationale TEXT NOT NULL CHECK (LENGTH(TRIM(rationale)) > 0),
    evidence_message_id BIGINT,
    evidence_action_id BIGINT,
    evidence_note TEXT,
    FOREIGN KEY (evaluation_id, session_id, case_version_id) REFERENCES public.session_evaluations (id, session_id, case_version_id) ON DELETE RESTRICT,
    FOREIGN KEY (case_version_id, rubric_item_id) REFERENCES public.rubric_items (case_version_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (session_id, evidence_message_id) REFERENCES public.session_messages (session_id, id) ON DELETE RESTRICT,
    FOREIGN KEY (session_id, evidence_action_id) REFERENCES public.session_actions (session_id, id) ON DELETE RESTRICT,
    UNIQUE (evaluation_id, rubric_item_id)
);

-- 25. tutor_conversations
CREATE TABLE public.tutor_conversations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id BIGINT NOT NULL,
    topic_id BIGINT,
    lesson_id BIGINT,
    title VARCHAR(200) CHECK (title IS NULL OR LENGTH(TRIM(title)) > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES public.student_profiles (user_id) ON DELETE RESTRICT,
    FOREIGN KEY (topic_id) REFERENCES public.topics (id) ON DELETE RESTRICT,
    FOREIGN KEY (lesson_id) REFERENCES public.lessons (id) ON DELETE RESTRICT,
    CHECK (topic_id IS NULL OR lesson_id IS NULL)
);

-- 26. tutor_messages
CREATE TABLE public.tutor_messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    speaker VARCHAR(20) NOT NULL CHECK (speaker IN ('student','assistant')),
    message_text TEXT NOT NULL CHECK (LENGTH(TRIM(message_text)) > 0),
    sequence_number INTEGER NOT NULL CHECK (sequence_number >= 1),
    model_name VARCHAR(150) CHECK (model_name IS NULL OR LENGTH(TRIM(model_name)) > 0),
    prompt_version VARCHAR(100) CHECK (prompt_version IS NULL OR LENGTH(TRIM(prompt_version)) > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES public.tutor_conversations (id) ON DELETE RESTRICT,
    UNIQUE (conversation_id, sequence_number),
    CHECK (speaker = 'assistant' OR (model_name IS NULL AND prompt_version IS NULL))
);

-- Supporting and partial unique indexes
CREATE UNIQUE INDEX users_email_unique ON public.users (LOWER(TRIM(email)));
CREATE INDEX topics_subject_id_idx ON public.topics (subject_id);
CREATE INDEX lessons_topic_id_idx ON public.lessons (topic_id);
CREATE INDEX lesson_progress_lesson_id_idx ON public.lesson_progress (lesson_id);
CREATE INDEX lesson_sources_document_id_idx ON public.lesson_sources (source_document_id);
CREATE INDEX questions_topic_id_idx ON public.questions (topic_id);
CREATE INDEX questions_source_document_id_idx ON public.questions (source_document_id);
CREATE UNIQUE INDEX question_options_one_correct_idx ON public.question_options (question_id) WHERE is_correct = TRUE;
CREATE INDEX quiz_attempts_student_id_idx ON public.quiz_attempts (student_id);
CREATE INDEX quiz_attempt_items_question_id_idx ON public.quiz_attempt_items (question_id);
CREATE UNIQUE INDEX case_versions_one_published_idx ON public.case_versions (case_id) WHERE status = 'published';
CREATE INDEX case_versions_reviewed_by_idx ON public.case_versions (reviewed_by);
CREATE INDEX case_sources_document_id_idx ON public.case_sources (source_document_id);
CREATE INDEX osce_sessions_student_id_idx ON public.osce_sessions (student_id);
CREATE INDEX osce_sessions_case_version_id_idx ON public.osce_sessions (case_version_id);
CREATE INDEX session_actions_session_version_idx ON public.session_actions (session_id, case_version_id);
CREATE INDEX session_actions_finding_version_idx ON public.session_actions (case_version_id, finding_id);
CREATE INDEX session_evaluations_case_version_id_idx ON public.session_evaluations (case_version_id);
CREATE INDEX evaluation_items_rubric_idx ON public.evaluation_items (case_version_id, rubric_item_id);
CREATE INDEX evaluation_items_message_idx ON public.evaluation_items (session_id, evidence_message_id);
CREATE INDEX evaluation_items_action_idx ON public.evaluation_items (session_id, evidence_action_id);
CREATE INDEX tutor_conversations_student_id_idx ON public.tutor_conversations (student_id);
CREATE INDEX tutor_conversations_topic_id_idx ON public.tutor_conversations (topic_id);
CREATE INDEX tutor_conversations_lesson_id_idx ON public.tutor_conversations (lesson_id);


-- 27. Authentication sessions
CREATE TABLE public.auth_sessions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    user_id BIGINT NOT NULL,

    token_hash VARCHAR(64) NOT NULL UNIQUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,

    CONSTRAINT auth_sessions_user_fk
        FOREIGN KEY (user_id)
        REFERENCES public.users(id)
        ON DELETE RESTRICT,

    CONSTRAINT auth_sessions_token_hash_valid
        CHECK (token_hash ~ '^[0-9a-f]{64}$'),

    CONSTRAINT auth_sessions_expiry_valid
        CHECK (expires_at > created_at),

    CONSTRAINT auth_sessions_revocation_valid
        CHECK (
            revoked_at IS NULL
            OR revoked_at >= created_at
        )
);

CREATE INDEX auth_sessions_user_id_idx
    ON public.auth_sessions(user_id);

CREATE INDEX auth_sessions_expires_at_idx
    ON public.auth_sessions(expires_at);

COMMIT;
