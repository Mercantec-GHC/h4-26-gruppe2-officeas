-- ======================
-- CONVERSATIONS
-- ======================

CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_id UUID NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
    is_group BOOLEAN NOT NULL DEFAULT FALSE,
    last_message_at TIMESTAMP,
    last_message_preview TEXT DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_conversation_department ON conversations(department_id);
CREATE INDEX idx_conversation_last_msg ON conversations(last_message_at);

-- ======================
-- CONVERSATION MEMBERS
-- ======================

CREATE TABLE conversation_members (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE UNIQUE INDEX idx_conv_member_unique ON conversation_members(conversation_id, user_id);
CREATE INDEX idx_conv_member_conv ON conversation_members(conversation_id);
CREATE INDEX idx_conv_member_user ON conversation_members(user_id);

-- ======================
-- MESSAGES (content encrypted at rest via AES-256-GCM)
-- ======================

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    read_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX idx_message_conv ON messages(conversation_id);
CREATE INDEX idx_message_sender ON messages(sender_id);
CREATE INDEX idx_msg_conv_created ON messages(conversation_id, created_at);
CREATE INDEX idx_msg_unread ON messages(conversation_id, sender_id, read_at);

-- ======================
-- DEVICE TOKENS (push notifications)
-- ======================

CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(512) NOT NULL UNIQUE,
    platform VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_token_user ON device_tokens(user_id);
