-- ============================================================================
-- MOBI: In-app chat foundation
-- ============================================================================
-- Adds:
--   - chat_conversations
--   - chat_messages
--   - participant-scoped RLS
--   - get-or-create conversation RPC
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chat_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid REFERENCES public.trips(id) ON DELETE CASCADE,
  participant_low_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  participant_high_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  context_type text NOT NULL DEFAULT 'direct'
    CHECK (context_type IN ('direct', 'trip')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived', 'closed')),
  last_message_at timestamptz,
  last_message_preview text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (participant_low_id <> participant_high_id),
  CHECK (
    (context_type = 'trip' AND trip_id IS NOT NULL) OR
    (context_type = 'direct')
  )
);

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  message_type text NOT NULL DEFAULT 'text'
    CHECK (message_type IN ('text', 'system')),
  body text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_conversations_trip_pair
  ON public.chat_conversations (trip_id, participant_low_id, participant_high_id)
  WHERE trip_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_conversations_direct_pair
  ON public.chat_conversations (participant_low_id, participant_high_id)
  WHERE trip_id IS NULL AND context_type = 'direct';

CREATE INDEX IF NOT EXISTS idx_chat_conversations_trip
  ON public.chat_conversations (trip_id, last_message_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_participant_low
  ON public.chat_conversations (participant_low_id, last_message_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_chat_conversations_participant_high
  ON public.chat_conversations (participant_high_id, last_message_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
  ON public.chat_messages (conversation_id, created_at ASC);

DROP TRIGGER IF EXISTS set_chat_conversations_updated_at ON public.chat_conversations;
CREATE TRIGGER set_chat_conversations_updated_at
  BEFORE UPDATE ON public.chat_conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE FUNCTION public.handle_chat_message_insert()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.chat_conversations
  SET last_message_at = NEW.created_at,
      last_message_preview = LEFT(NEW.body, 160),
      updated_at = now()
  WHERE id = NEW.conversation_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_chat_message_insert ON public.chat_messages;
CREATE TRIGGER on_chat_message_insert
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_chat_message_insert();

ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chat_conversations_select_participants ON public.chat_conversations;
CREATE POLICY chat_conversations_select_participants
  ON public.chat_conversations FOR SELECT
  TO authenticated
  USING (auth.uid() IN (participant_low_id, participant_high_id));

DROP POLICY IF EXISTS chat_conversations_insert_participants ON public.chat_conversations;
CREATE POLICY chat_conversations_insert_participants
  ON public.chat_conversations FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND auth.uid() IN (participant_low_id, participant_high_id)
  );

DROP POLICY IF EXISTS chat_conversations_update_participants ON public.chat_conversations;
CREATE POLICY chat_conversations_update_participants
  ON public.chat_conversations FOR UPDATE
  TO authenticated
  USING (auth.uid() IN (participant_low_id, participant_high_id))
  WITH CHECK (auth.uid() IN (participant_low_id, participant_high_id));

DROP POLICY IF EXISTS chat_messages_select_participants ON public.chat_messages;
CREATE POLICY chat_messages_select_participants
  ON public.chat_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.chat_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (conversation.participant_low_id, conversation.participant_high_id)
    )
  );

DROP POLICY IF EXISTS chat_messages_insert_sender ON public.chat_messages;
CREATE POLICY chat_messages_insert_sender
  ON public.chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.chat_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (conversation.participant_low_id, conversation.participant_high_id)
    )
  );

DROP POLICY IF EXISTS chat_messages_update_participants ON public.chat_messages;
CREATE POLICY chat_messages_update_participants
  ON public.chat_messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.chat_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (conversation.participant_low_id, conversation.participant_high_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.chat_conversations AS conversation
      WHERE conversation.id = conversation_id
        AND auth.uid() IN (conversation.participant_low_id, conversation.participant_high_id)
    )
  );

CREATE OR REPLACE FUNCTION public.rpc_get_or_create_chat_conversation(
  p_peer_id uuid,
  p_trip_id uuid DEFAULT NULL
)
RETURNS public.chat_conversations
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_self_id uuid := auth.uid();
  v_trip public.trips%ROWTYPE;
  v_conversation public.chat_conversations%ROWTYPE;
  v_low_id uuid;
  v_high_id uuid;
  v_context_type text := CASE WHEN p_trip_id IS NULL THEN 'direct' ELSE 'trip' END;
BEGIN
  IF v_self_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_peer_id IS NULL OR p_peer_id = v_self_id THEN
    RAISE EXCEPTION 'A different peer is required';
  END IF;

  IF p_trip_id IS NOT NULL THEN
    SELECT *
    INTO v_trip
    FROM public.trips
    WHERE id = p_trip_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Trip not found';
    END IF;

    IF v_self_id <> v_trip.author_id AND p_peer_id <> v_trip.author_id THEN
      RAISE EXCEPTION 'Trip chat must include the trip author';
    END IF;
  END IF;

  v_low_id := LEAST(v_self_id, p_peer_id);
  v_high_id := GREATEST(v_self_id, p_peer_id);

  SELECT *
  INTO v_conversation
  FROM public.chat_conversations
  WHERE participant_low_id = v_low_id
    AND participant_high_id = v_high_id
    AND (
      (p_trip_id IS NULL AND trip_id IS NULL AND context_type = 'direct')
      OR trip_id = p_trip_id
    )
  LIMIT 1;

  IF FOUND THEN
    RETURN v_conversation;
  END IF;

  INSERT INTO public.chat_conversations (
    trip_id,
    participant_low_id,
    participant_high_id,
    created_by,
    context_type
  )
  VALUES (
    p_trip_id,
    v_low_id,
    v_high_id,
    v_self_id,
    v_context_type
  )
  RETURNING *
  INTO v_conversation;

  INSERT INTO public.chat_messages (
    conversation_id,
    sender_id,
    message_type,
    body,
    metadata
  )
  VALUES (
    v_conversation.id,
    NULL,
    'system',
    'Chat started in MOBI. Keep trip planning, pricing, and pickup details here without sharing personal contact details.',
    jsonb_build_object('seed', 'privacy_notice')
  );

  RETURN v_conversation;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_get_or_create_chat_conversation(uuid, uuid) TO authenticated;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN undefined_object THEN NULL;
  END;
END;
$$;
