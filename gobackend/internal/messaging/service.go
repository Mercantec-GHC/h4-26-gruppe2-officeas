package messaging

import (
	"errors"
	"log"
	"strings"
	"time"
	"unicode/utf8"

	"stuff/internal/security"
	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// MaxMessageLength is the hard limit on plaintext message length (rune count).
const MaxMessageLength = 2000

// previewLength is the max runes stored in Conversation.LastMessagePreview.
const previewLength = 80

// Sentinel errors returned by Service methods.
var (
	ErrNotMember       = errors.New("user is not a member of this conversation")
	ErrWrongDepartment = errors.New("conversation does not belong to user's department")
	ErrMessageTooLong  = errors.New("message exceeds maximum length of 2000 characters")
	ErrEmptyMessage    = errors.New("message content must not be empty")
	ErrMessageNotFound = errors.New("message not found")
	ErrConvNotFound    = errors.New("conversation not found")
	ErrForbiddenDelete = errors.New("forbidden: only sender can delete this message")
)

// Service contains all messaging business logic.
// Handlers delegate to this layer rather than touching encryption or DB directly.
type Service struct {
	db          *gorm.DB
	encryptor   *security.Encryptor
	rateLimiter *MessageRateLimiter
	audit       *AuditLogger
	notifier    NotificationSender
	hub         *Hub // Set after hub is created to break circular init
}

// NotificationSender sends push notifications. Implement with FCM/APNs for real delivery.
type NotificationSender interface {
	SendPush(userID uuid.UUID, title, body string) error
}

// NoopNotificationSender just logs — replace with a real sender in production.
type NoopNotificationSender struct{}

func (n *NoopNotificationSender) SendPush(userID uuid.UUID, title, body string) error {
	log.Printf("[NOTIFICATION] push queued (noop) | user=%s title=%q", userID, title)
	return nil
}

// NewService constructs a Service with all required dependencies.
func NewService(
	db *gorm.DB,
	enc *security.Encryptor,
	rl *MessageRateLimiter,
	audit *AuditLogger,
	notifier NotificationSender,
) *Service {
	return &Service{
		db:          db,
		encryptor:   enc,
		rateLimiter: rl,
		audit:       audit,
		notifier:    notifier,
	}
}

// SetHub wires the hub in after both Service and Hub are created (avoids circular init).
func (s *Service) SetHub(h *Hub) {
	s.hub = h
}

// ---------------------------------------------------------------------------
// CreateConversation
// ---------------------------------------------------------------------------

// CreateConversation creates a conversation scoped to the creator's department.
// Users may come from different departments; creator must be included.
func (s *Service) CreateConversation(creatorID uuid.UUID, departmentID uuid.UUID, userIDs []uuid.UUID, isGroup bool) (*models.ConversationDTO, error) {
	// Deduplicate user IDs to prevent duplicate membership attempts
	seen := make(map[uuid.UUID]struct{}, len(userIDs))
	unique := make([]uuid.UUID, 0, len(userIDs))
	for _, uid := range userIDs {
		if _, dup := seen[uid]; !dup {
			seen[uid] = struct{}{}
			unique = append(unique, uid)
		}
	}
	userIDs = unique

	if len(userIDs) < 2 {
		return nil, errors.New("a conversation needs at least 2 unique members")
	}

	// Ensure the creator is included in the member list
	if _, ok := seen[creatorID]; !ok {
		return nil, errors.New("creator must be included in the member list")
	}

	// Verify all users exist
	var count int64
	s.db.Model(&models.User{}).
		Where("id IN ?", userIDs).
		Count(&count)
	if int(count) != len(userIDs) {
		return nil, errors.New("one or more users were not found")
	}

	// For 1:1 chats, return existing conversation if one already exists.
	if !isGroup && len(userIDs) == 2 {
		if existing, err := s.findExisting1on1(userIDs[0], userIDs[1], creatorID); err == nil && existing != nil {
			return existing, nil
		}
	}

	conv := models.Conversation{
		Id:           uuid.New(),
		DepartmentId: departmentID,
		IsGroup:      isGroup,
	}

	// Use a transaction so both conversation and members are created atomically.
	members := make([]models.ConversationMember, len(userIDs))
	for i, uid := range userIDs {
		members[i] = models.ConversationMember{
			ConversationId: conv.Id,
			UserId:         uid,
			JoinedAt:       time.Now(),
		}
	}

	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&conv).Error; err != nil {
			return err
		}
		return tx.Create(&members).Error
	})
	if err != nil {
		return nil, err
	}

	s.audit.LogConversationCreated(creatorID, conv.Id, len(userIDs))

	return s.conversationToDTO(conv, creatorID)
}

// ---------------------------------------------------------------------------
// SendMessage
// ---------------------------------------------------------------------------

// SendMessage validates, encrypts, persists a message, updates the conversation
// preview, and broadcasts the result to online members.
func (s *Service) SendMessage(senderID uuid.UUID, conversationID uuid.UUID, content string) (*models.MessageDTO, error) {
	// --- Validation ---
	if content == "" {
		return nil, ErrEmptyMessage
	}
	if utf8.RuneCountInString(content) > MaxMessageLength {
		return nil, ErrMessageTooLong
	}

	// Rate limit check
	if err := s.rateLimiter.Allow(senderID); err != nil {
		s.audit.LogRateLimited(senderID)
		return nil, err
	}

	// Verify membership
	if err := s.verifyMembership(senderID, conversationID); err != nil {
		return nil, err
	}

	// --- Encrypt ---
	encrypted, err := s.encryptor.Encrypt(content)
	if err != nil {
		return nil, err
	}

	// --- Persist ---
	now := time.Now()
	msg := models.Message{
		Id:             uuid.New(),
		ConversationId: conversationID,
		SenderId:       senderID,
		Content:        encrypted,
		CreatedAt:      now,
	}

	// Encrypt preview so no plaintext is stored at rest.
	preview := truncateRunes(content, previewLength)
	encryptedPreview, err := s.encryptor.Encrypt(preview)
	if err != nil {
		return nil, err
	}

	err = s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&msg).Error; err != nil {
			return err
		}
		// Update conversation tracking fields
		return tx.Model(&models.Conversation{}).
			Where("id = ?", conversationID).
			Updates(map[string]interface{}{
				"last_message_at":      now,
				"last_message_preview": encryptedPreview,
			}).Error
	})
	if err != nil {
		return nil, err
	}

	s.audit.LogMessageSent(senderID, conversationID, msg.Id)

	// --- Build DTO with decrypted content ---
	var sender models.User
	s.db.Select("id, name").First(&sender, "id = ?", senderID)

	dto := &models.MessageDTO{
		Id:             msg.Id,
		ConversationId: conversationID,
		SenderId:       senderID,
		SenderName:     sender.Name,
		Content:        content, // plaintext for the DTO
		CreatedAt:      now,
		ReadAt:         nil,
	}

	// --- Broadcast to online members ---
	if s.hub != nil {
		memberIDs, _ := s.getMemberIDs(conversationID)
		event := models.WebSocketEvent{
			Type:    "new_message",
			Payload: dto,
		}
		s.hub.BroadcastToUsers(memberIDs, event)

		relatedType := "conversation"
		relatedID := conversationID

		// Notify members
		for _, uid := range memberIDs {
			if uid == senderID {
				continue
			}

			notification := models.Notification{
				Id:                uuid.New(),
				UserId:            uid,
				Title:             "New message",
				Message:           sender.Name + ": " + preview,
				Type:              models.NotificationTypeMessageReceived,
				CreatedAt:         now,
				RelatedEntityId:   &relatedID,
				RelatedEntityType: &relatedType,
			}
			if err := s.db.Create(&notification).Error; err != nil {
				log.Printf("[NOTIFICATION] failed to persist message notification | user=%s err=%v", uid, err)
			}

			if !s.hub.IsOnline(uid) {
				_ = s.notifier.SendPush(uid, "New Message", sender.Name+": "+preview)
			}
		}
	}

	return dto, nil
}

// ---------------------------------------------------------------------------
// GetMessages (paginated)
// ---------------------------------------------------------------------------

// GetMessages returns a page of messages (newest first).
// Soft-deleted messages are excluded by GORM.
func (s *Service) GetMessages(userID uuid.UUID, conversationID uuid.UUID, limit, offset int) (*models.PaginatedMessages, error) {
	if err := s.verifyMembership(userID, conversationID); err != nil {
		return nil, err
	}

	// Clamp pagination values
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	var total int64
	s.db.Model(&models.Message{}).
		Where("conversation_id = ?", conversationID).
		Count(&total)

	var messages []models.Message
	err := s.db.
		Where("conversation_id = ?", conversationID).
		Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&messages).Error
	if err != nil {
		return nil, err
	}

	// Decrypt and build DTOs
	dtos := make([]models.MessageDTO, 0, len(messages))
	// Cache sender names to avoid repeated DB hits within one page
	nameCache := make(map[uuid.UUID]string)
	var decryptFailures int64

	for _, m := range messages {
		plaintext, err := s.encryptor.Decrypt(m.Content)
		if err != nil {
			// If decryption fails log metadata and skip — do not expose errors
			log.Printf("[WARN] decrypt failed for message=%s in conversation=%s", m.Id, m.ConversationId)
			decryptFailures++
			continue
		}

		name, ok := nameCache[m.SenderId]
		if !ok {
			var u models.User
			s.db.Select("id, name").First(&u, "id = ?", m.SenderId)
			name = u.Name
			nameCache[m.SenderId] = name
		}

		dtos = append(dtos, models.MessageDTO{
			Id:             m.Id,
			ConversationId: m.ConversationId,
			SenderId:       m.SenderId,
			SenderName:     name,
			Content:        plaintext,
			CreatedAt:      m.CreatedAt,
			ReadAt:         m.ReadAt,
		})
	}

	return &models.PaginatedMessages{
		Messages: dtos,
		Total:    total - decryptFailures,
		Limit:    limit,
		Offset:   offset,
	}, nil
}

// ---------------------------------------------------------------------------
// MarkAsRead
// ---------------------------------------------------------------------------

// MarkAsRead sets ReadAt on a message. Only the recipient should call this.
func (s *Service) MarkAsRead(userID uuid.UUID, messageID uuid.UUID) error {
	var msg models.Message
	if err := s.db.First(&msg, "id = ?", messageID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrMessageNotFound
		}
		return err
	}

	// Sender cannot mark their own message as read
	if msg.SenderId == userID {
		return nil // no-op, not an error
	}

	if err := s.verifyMembership(userID, msg.ConversationId); err != nil {
		return err
	}

	now := time.Now()
	if err := s.db.Model(&msg).Update("read_at", now).Error; err != nil {
		return err
	}

	s.audit.LogMessageRead(userID, messageID)

	// Broadcast read receipt to conversation members
	if s.hub != nil {
		memberIDs, _ := s.getMemberIDs(msg.ConversationId)
		event := models.WebSocketEvent{
			Type: "message_read",
			Payload: map[string]interface{}{
				"message_id":      messageID,
				"conversation_id": msg.ConversationId,
				"read_by":         userID,
				"read_at":         now,
			},
		}
		s.hub.BroadcastToUsers(memberIDs, event)
	}

	return nil
}

// ---------------------------------------------------------------------------
// GetUnreadCount
// ---------------------------------------------------------------------------

// GetUnreadCount returns unread messages in a conversation for the given user.
func (s *Service) GetUnreadCount(userID uuid.UUID, conversationID uuid.UUID) (int64, error) {
	if err := s.verifyMembership(userID, conversationID); err != nil {
		return 0, err
	}

	var count int64
	err := s.db.Model(&models.Message{}).
		Where("conversation_id = ? AND sender_id != ? AND read_at IS NULL", conversationID, userID).
		Count(&count).Error
	return count, err
}

// DeleteMessage soft-deletes a message. Only sender or Ledelse may delete.
func (s *Service) DeleteMessage(userID uuid.UUID, messageID uuid.UUID) error {
	var msg models.Message
	if err := s.db.First(&msg, "id = ?", messageID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrMessageNotFound
		}
		return err
	}

	var user models.User
	if err := s.db.Preload("Department").First(&user, "id = ?", userID).Error; err != nil {
		return err
	}

	isLedelse := strings.EqualFold(strings.TrimSpace(user.Department.Name), "Ledelse")
	if msg.SenderId != userID && !isLedelse {
		return ErrForbiddenDelete
	}

	if err := s.db.Where("id = ?", messageID).Delete(&models.Message{}).Error; err != nil {
		return err
	}

	log.Printf("[AUDIT] message_soft_deleted | deleted_by=%s message=%s time=%s",
		userID, messageID, time.Now().UTC().Format(time.RFC3339))

	return nil
}

// ---------------------------------------------------------------------------
// GetConversations — list conversations for a user
// ---------------------------------------------------------------------------

// GetConversations returns all conversations the user belongs to, newest first.
func (s *Service) GetConversations(userID uuid.UUID) ([]models.ConversationDTO, error) {
	var memberships []models.ConversationMember
	err := s.db.Where("user_id = ?", userID).Find(&memberships).Error
	if err != nil {
		return nil, err
	}

	convIDs := make([]uuid.UUID, len(memberships))
	for i, m := range memberships {
		convIDs[i] = m.ConversationId
	}

	if len(convIDs) == 0 {
		return []models.ConversationDTO{}, nil
	}

	var conversations []models.Conversation
	err = s.db.
		Where("id IN ?", convIDs).
		Order("last_message_at DESC NULLS LAST").
		Find(&conversations).Error
	if err != nil {
		return nil, err
	}

	dtos := make([]models.ConversationDTO, 0, len(conversations))
	for _, c := range conversations {
		dto, err := s.conversationToDTO(c, userID)
		if err != nil {
			continue
		}
		dtos = append(dtos, *dto)
	}

	return dtos, nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// verifyMembership checks that the user is a member of the given conversation.
func (s *Service) verifyMembership(userID, conversationID uuid.UUID) error {
	var count int64
	s.db.Model(&models.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", conversationID, userID).
		Count(&count)
	if count == 0 {
		return ErrNotMember
	}
	return nil
}

// getMemberIDs returns all user IDs that are members of the conversation.
func (s *Service) getMemberIDs(conversationID uuid.UUID) ([]uuid.UUID, error) {
	var ids []uuid.UUID
	err := s.db.Model(&models.ConversationMember{}).
		Where("conversation_id = ?", conversationID).
		Pluck("user_id", &ids).Error
	return ids, err
}

// conversationToDTO builds a DTO with member info and unread count.
func (s *Service) conversationToDTO(conv models.Conversation, forUserID uuid.UUID) (*models.ConversationDTO, error) {
	var members []models.ConversationMember
	s.db.Preload("User").Where("conversation_id = ?", conv.Id).Find(&members)

	memberDTOs := make([]models.ConversationMemberDTO, 0, len(members))
	for _, m := range members {
		memberDTOs = append(memberDTOs, models.ConversationMemberDTO{
			UserId:   m.UserId,
			UserName: m.User.Name,
			JoinedAt: m.JoinedAt,
		})
	}

	// Skip verifyMembership — caller already proved membership by being in the list
	var unread int64
	s.db.Model(&models.Message{}).
		Where("conversation_id = ? AND sender_id != ? AND read_at IS NULL", conv.Id, forUserID).
		Count(&unread)

	// Decrypt the preview for the API response
	decryptedPreview := ""
	if conv.LastMessagePreview != "" {
		if p, err := s.encryptor.Decrypt(conv.LastMessagePreview); err == nil {
			decryptedPreview = p
		}
	}

	return &models.ConversationDTO{
		Id:                 conv.Id,
		DepartmentId:       conv.DepartmentId,
		IsGroup:            conv.IsGroup,
		LastMessageAt:      conv.LastMessageAt,
		LastMessagePreview: decryptedPreview,
		UnreadCount:        unread,
		Members:            memberDTOs,
		CreatedAt:          conv.CreatedAt,
		UpdatedAt:          conv.UpdatedAt,
	}, nil
}

// findExisting1on1 looks for an existing 1:1 conversation between two users.
func (s *Service) findExisting1on1(userA, userB uuid.UUID, forUserID uuid.UUID) (*models.ConversationDTO, error) {
	// Find conversation IDs where both users are members.
	var convIDs []uuid.UUID
	err := s.db.Model(&models.ConversationMember{}).
		Select("conversation_id").
		Where("user_id IN ?", []uuid.UUID{userA, userB}).
		Group("conversation_id").
		Having("COUNT(DISTINCT user_id) = 2").
		Pluck("conversation_id", &convIDs).Error
	if err != nil || len(convIDs) == 0 {
		return nil, err
	}

	// Among those, find one that is NOT a group and has exactly 2 members.
	var conv models.Conversation
	err = s.db.
		Where("id IN ? AND is_group = false", convIDs).
		Order("created_at ASC").
		First(&conv).Error
	if err != nil {
		return nil, err
	}

	// Verify it has exactly 2 members (not a coincidence of a larger group).
	var memberCount int64
	s.db.Model(&models.ConversationMember{}).Where("conversation_id = ?", conv.Id).Count(&memberCount)
	if memberCount != 2 {
		return nil, nil // not a strict 1:1
	}

	return s.conversationToDTO(conv, forUserID)
}

// GetUserDepartmentID looks up a user's department ID from the database.
func (s *Service) GetUserDepartmentID(userID uuid.UUID) (uuid.UUID, error) {
	var user models.User
	if err := s.db.Select("id, department_id").First(&user, "id = ?", userID).Error; err != nil {
		return uuid.Nil, err
	}
	return user.DepartmentId, nil
}

// truncateRunes truncates a string to at most maxRunes runes, appending "…" if truncated.
func truncateRunes(s string, maxRunes int) string {
	runes := []rune(s)
	if len(runes) <= maxRunes {
		return s
	}
	return string(runes[:maxRunes]) + "…"
}
