BEGIN;

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