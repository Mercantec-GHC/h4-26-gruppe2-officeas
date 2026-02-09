package messaging

import (
	"log"
	"time"

	"github.com/google/uuid"
)

// AuditLogger logs metadata for messaging operations.
// Never logs message content — only IDs and timestamps.
// Swap in a structured logger (Zap, etc.) for production.
type AuditLogger struct {
	logger *log.Logger
}

// NewAuditLogger creates an AuditLogger that writes to the standard logger.
func NewAuditLogger() *AuditLogger {
	return &AuditLogger{
		logger: log.Default(),
	}
}

// LogMessageSent logs that a message was sent (metadata only, no content).
func (a *AuditLogger) LogMessageSent(senderID, conversationID, messageID uuid.UUID) {
	a.logger.Printf("[AUDIT] message_sent | sender=%s conversation=%s message=%s time=%s",
		senderID, conversationID, messageID, time.Now().UTC().Format(time.RFC3339))
}

// LogMessageRead records that a message was marked as read.
func (a *AuditLogger) LogMessageRead(userID, messageID uuid.UUID) {
	a.logger.Printf("[AUDIT] message_read | user=%s message=%s time=%s",
		userID, messageID, time.Now().UTC().Format(time.RFC3339))
}

// LogConversationCreated records that a new conversation was created.
func (a *AuditLogger) LogConversationCreated(creatorID, conversationID uuid.UUID, memberCount int) {
	a.logger.Printf("[AUDIT] conversation_created | creator=%s conversation=%s members=%d time=%s",
		creatorID, conversationID, memberCount, time.Now().UTC().Format(time.RFC3339))
}

// LogWebSocketConnect records a WebSocket connection event.
func (a *AuditLogger) LogWebSocketConnect(userID uuid.UUID) {
	a.logger.Printf("[AUDIT] ws_connect | user=%s time=%s",
		userID, time.Now().UTC().Format(time.RFC3339))
}

// LogWebSocketDisconnect records a WebSocket disconnection event.
func (a *AuditLogger) LogWebSocketDisconnect(userID uuid.UUID) {
	a.logger.Printf("[AUDIT] ws_disconnect | user=%s time=%s",
		userID, time.Now().UTC().Format(time.RFC3339))
}

// LogRateLimited records that a user hit the message rate limit.
func (a *AuditLogger) LogRateLimited(userID uuid.UUID) {
	a.logger.Printf("[AUDIT] rate_limited | user=%s time=%s",
		userID, time.Now().UTC().Format(time.RFC3339))
}
