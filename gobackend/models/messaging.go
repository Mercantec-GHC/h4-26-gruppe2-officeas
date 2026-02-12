package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Conversation is a messaging thread scoped to a department.
// IsGroup distinguishes 1:1 chats from group chats.
type Conversation struct {
	Id                 uuid.UUID  `gorm:"type:uuid;primaryKey" json:"id"`
	DepartmentId       uuid.UUID  `gorm:"type:uuid;not null;index:idx_conversation_department" json:"department_id"`
	IsGroup            bool       `gorm:"default:false" json:"is_group"`
	LastMessageAt      *time.Time `gorm:"index:idx_conversation_last_msg" json:"last_message_at"`
	LastMessagePreview string     `gorm:"type:text" json:"last_message_preview"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`

	// Relations
	Department Department           `gorm:"foreignKey:DepartmentId;constraint:OnDelete:CASCADE" json:"department,omitempty"`
	Members    []ConversationMember `gorm:"foreignKey:ConversationId;constraint:OnDelete:CASCADE" json:"members,omitempty"`
	Messages   []Message            `gorm:"foreignKey:ConversationId;constraint:OnDelete:CASCADE" json:"messages,omitempty"`
}

// ConversationMember links a user to a conversation.
// Unique constraint on (ConversationId, UserId) prevents duplicates.
type ConversationMember struct {
	ConversationId uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_conv_member_unique;index:idx_conv_member_conv" json:"conversation_id"`
	UserId         uuid.UUID `gorm:"type:uuid;not null;uniqueIndex:idx_conv_member_unique;index:idx_conv_member_user" json:"user_id"`
	JoinedAt       time.Time `gorm:"autoCreateTime" json:"joined_at"`

	// Relations
	Conversation Conversation `gorm:"foreignKey:ConversationId;constraint:OnDelete:CASCADE" json:"conversation,omitempty"`
	User         User         `gorm:"foreignKey:UserId;constraint:OnDelete:CASCADE" json:"user,omitempty"`
}

// Message is an encrypted message in a conversation.
// Content is AES-256-GCM ciphertext (base64). DeletedAt = soft delete.
type Message struct {
	Id             uuid.UUID      `gorm:"type:uuid;primaryKey" json:"id"`
	ConversationId uuid.UUID      `gorm:"type:uuid;not null;index:idx_message_conv;index:idx_msg_conv_created;index:idx_msg_unread" json:"conversation_id"`
	SenderId       uuid.UUID      `gorm:"type:uuid;not null;index:idx_message_sender;index:idx_msg_unread" json:"sender_id"`
	Content        string         `gorm:"type:text;not null" json:"content"` // Encrypted at rest
	CreatedAt      time.Time      `gorm:"index:idx_msg_conv_created" json:"created_at"`
	ReadAt         *time.Time     `gorm:"index:idx_msg_unread" json:"read_at"`
	DeletedAt      gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"` // Soft delete

	// Relations
	Conversation Conversation `gorm:"foreignKey:ConversationId;constraint:OnDelete:CASCADE" json:"conversation,omitempty"`
	Sender       User         `gorm:"foreignKey:SenderId;constraint:OnDelete:CASCADE" json:"sender,omitempty"`
}

// DeviceToken stores push notification tokens per user/platform.
type DeviceToken struct {
	Id        uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	UserId    uuid.UUID `gorm:"type:uuid;not null;index:idx_device_token_user" json:"user_id"`
	Token     string    `gorm:"type:varchar(512);not null;uniqueIndex" json:"token"`
	Platform  string    `gorm:"type:varchar(20);not null" json:"platform"` // "ios" or "android"
	CreatedAt time.Time `json:"created_at"`

	// Relations
	User User `gorm:"foreignKey:UserId;constraint:OnDelete:CASCADE" json:"user,omitempty"`
}
