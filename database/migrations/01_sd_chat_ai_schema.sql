-- ====================================================================
-- SD CHAT AI — MIGRATION 11 : SOCLE CONVERSATIONNEL & MESSAGERIE (SD-DEV)
-- Description : Tables chat_conversations, chat_messages, chat_attachments,
--               chat_user_usage, bucket Storage chat-attachments et RLS.
-- Base cible  : SD-DEV (ryvmacsmfvllhgbqbnkb)
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TABLE DES CONVERSATIONS (chat_conversations)
CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'Nouvelle conversation',
    model TEXT NOT NULL DEFAULT 'gemini-3.6-flash',
    system_prompt TEXT,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_user ON public.chat_conversations(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_conversations_archived ON public.chat_conversations(user_id, is_archived);

-- Trigger pour la mise à jour automatique de updated_at
CREATE OR REPLACE FUNCTION public.handle_chat_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_chat_conversations_updated_at ON public.chat_conversations;
CREATE TRIGGER tr_chat_conversations_updated_at
    BEFORE UPDATE ON public.chat_conversations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_chat_updated_at();

-- RLS pour chat_conversations
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_conversations_owner_access" ON public.chat_conversations;
CREATE POLICY "chat_conversations_owner_access"
    ON public.chat_conversations FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- 3. TABLE DES MESSAGES (chat_messages)
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL DEFAULT '',
    tokens_used INTEGER NOT NULL DEFAULT 0,
    model TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conv ON public.chat_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user ON public.chat_messages(user_id);

-- Trigger pour actualiser le timestamp updated_at de la conversation lors d'un nouveau message
CREATE OR REPLACE FUNCTION public.handle_new_chat_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chat_conversations
    SET updated_at = NOW()
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_chat_messages_conv_update ON public.chat_messages;
CREATE TRIGGER tr_chat_messages_conv_update
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_chat_message();

-- RLS pour chat_messages
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_messages_owner_access" ON public.chat_messages;
CREATE POLICY "chat_messages_owner_access"
    ON public.chat_messages FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- 4. TABLE DES PIÈCES JOINTES (chat_attachments)
CREATE TABLE IF NOT EXISTS public.chat_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    message_id UUID REFERENCES public.chat_messages(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL CHECK (file_type IN ('image', 'text')),
    storage_path TEXT NOT NULL,
    mime_type TEXT NOT NULL DEFAULT 'application/octet-stream',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_attachments_conv ON public.chat_attachments(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_attachments_msg ON public.chat_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_chat_attachments_user ON public.chat_attachments(user_id);

-- RLS pour chat_attachments
ALTER TABLE public.chat_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_attachments_owner_access" ON public.chat_attachments;
CREATE POLICY "chat_attachments_owner_access"
    ON public.chat_attachments FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- 5. TABLE DES QUOTAS & USAGE (chat_user_usage)
CREATE TABLE IF NOT EXISTS public.chat_user_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    period_start DATE NOT NULL DEFAULT (date_trunc('month', NOW()))::DATE,
    messages_sent INTEGER NOT NULL DEFAULT 0,
    tokens_used BIGINT NOT NULL DEFAULT 0,
    attachments_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_chat_user_period UNIQUE(user_id, period_start)
);

CREATE INDEX IF NOT EXISTS idx_chat_user_usage_user ON public.chat_user_usage(user_id, period_start);

DROP TRIGGER IF EXISTS tr_chat_user_usage_updated_at ON public.chat_user_usage;
CREATE TRIGGER tr_chat_user_usage_updated_at
    BEFORE UPDATE ON public.chat_user_usage
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_chat_updated_at();

-- RLS pour chat_user_usage
ALTER TABLE public.chat_user_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_user_usage_owner_access" ON public.chat_user_usage;
CREATE POLICY "chat_user_usage_owner_access"
    ON public.chat_user_usage FOR ALL
    USING (auth.uid()::text = user_id OR auth.role() = 'service_role')
    WITH CHECK (auth.uid()::text = user_id OR auth.role() = 'service_role');

-- 6. BUCKET SUPABASE STORAGE POUR LES ATTACHMENTS
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-attachments',
    'chat-attachments',
    false,
    10485760, -- 10 Mo max
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/gif',
        'text/plain',
        'text/markdown',
        'text/csv'
    ]
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 10485760;

-- Politiques Storage pour 'chat-attachments'
DROP POLICY IF EXISTS "chat_storage_select" ON storage.objects;
CREATE POLICY "chat_storage_select"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'chat-attachments'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR auth.role() = 'service_role'
        )
    );

DROP POLICY IF EXISTS "chat_storage_insert" ON storage.objects;
CREATE POLICY "chat_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'chat-attachments'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR auth.role() = 'service_role'
        )
    );

DROP POLICY IF EXISTS "chat_storage_delete" ON storage.objects;
CREATE POLICY "chat_storage_delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'chat-attachments'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR auth.role() = 'service_role'
        )
    );
