package models

import (
	"time"

	"github.com/google/uuid"
)

// ConversationDTO is the API response for a conversation, including the
// requesting user's unread count.
type ConversationDTO struct {
	Id                 uuid.UUID               `json:"id"`
	DepartmentId       uuid.UUID               `json:"department_id"`
	IsGroup            bool                    `json:"is_group"`
	LastMessageAt      *time.Time              `json:"last_message_at"`
	LastMessagePreview string                  `json:"last_message_preview"`
	UnreadCount        int64                   `json:"unread_count"`
	Members            []ConversationMemberDTO `json:"members"`
	CreatedAt          time.Time               `json:"created_at"`
	UpdatedAt          time.Time               `json:"updated_at"`
}

// ConversationMemberDTO is the API response for a conversation member.
type ConversationMemberDTO struct {
	UserId         uuid.UUID `json:"user_id"`
	UserName       string    `json:"user_name"`
	DepartmentName string    `json:"department_name"`
	JoinedAt       time.Time `json:"joined_at"`
}

// MessageDTO is the API response for a message (content is decrypted).
type MessageDTO struct {
	Id             uuid.UUID  `json:"id"`
	ConversationId uuid.UUID  `json:"conversation_id"`
	SenderId       uuid.UUID  `json:"sender_id"`
	SenderName     string     `json:"sender_name"`
	Content        string     `json:"content"` // Decrypted plaintext
	CreatedAt      time.Time  `json:"created_at"`
	ReadAt         *time.Time `json:"read_at"`
}

// PaginatedMessages wraps a page of messages with pagination metadata.
type PaginatedMessages struct {
	Messages []MessageDTO `json:"messages"`
	Total    int64        `json:"total"`
	Limit    int          `json:"limit"`
	Offset   int          `json:"offset"`
}

// CreateConversationRequest is the request body for creating a conversation.
type CreateConversationRequest struct {
	UserIDs []uuid.UUID `json:"user_ids"`
	IsGroup bool        `json:"is_group"`
}

// SendMessageRequest is the request body for sending a message.
type SendMessageRequest struct {
	Content string `json:"content"`
}

// WebSocketEvent represents a real-time event sent to connected clients.
type WebSocketEvent struct {
	Type    string      `json:"type"` // "new_message", "message_read", etc.
	Payload interface{} `json:"payload"`
}
