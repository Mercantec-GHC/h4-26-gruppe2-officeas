package handlers

import (
	"context"
	"net/http"
	"strings"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// Permission defines a named capability used for authorization checks.
type Permission string

const (
	TicketCreate         Permission = "TicketCreate"
	TicketView           Permission = "TicketView"
	TicketUpdate         Permission = "TicketUpdate"
	TicketAssign         Permission = "TicketAssign"
	TicketResolve        Permission = "TicketResolve"
	AbsenceRequestCreate Permission = "AbsenceRequestCreate"
	AbsenceRequestReview Permission = "AbsenceRequestReview"
	ShiftManage          Permission = "ShiftManage"
	ConversationAccess   Permission = "ConversationAccess"
	MessageSend          Permission = "MessageSend"
	NotificationRead     Permission = "NotificationRead"
	AdminFullAccess      Permission = "AdminFullAccess"
)

const (
	departmentLedelse   = "Ledelse"
	departmentHR        = "HR"
	departmentITSupport = "IT-Support"
)

type authContextKey string

const currentUserContextKey authContextKey = "currentUser"

// AuthorizationService provides centralized authorization logic.
type AuthorizationService struct {
	DB                    *gorm.DB
	departmentPermissions map[string]map[Permission]struct{}
}

var defaultAuthorizationService *AuthorizationService

// NewAuthorizationService creates a new authorization service with in-memory permission mapping.
func NewAuthorizationService(db *gorm.DB) *AuthorizationService {
	return &AuthorizationService{
		DB: db,
		departmentPermissions: map[string]map[Permission]struct{}{
			departmentLedelse: {
				TicketCreate:         {},
				TicketView:           {},
				TicketUpdate:         {},
				TicketAssign:         {},
				TicketResolve:        {},
				AbsenceRequestCreate: {},
				AbsenceRequestReview: {},
				ShiftManage:          {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
				AdminFullAccess:      {},
			},
			departmentITSupport: {
				TicketCreate:       {},
				TicketView:         {},
				TicketUpdate:       {},
				TicketAssign:       {},
				TicketResolve:      {},
				ConversationAccess: {},
				MessageSend:        {},
				NotificationRead:   {},
			},
			departmentHR: {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				AbsenceRequestReview: {},
				ShiftManage:          {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Økonomi": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Produkt": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Drift": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Kundeservice": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Salg": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Design": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Udvikling": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Datateam": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
			"Marketing": {
				TicketCreate:         {},
				TicketView:           {},
				AbsenceRequestCreate: {},
				ConversationAccess:   {},
				MessageSend:          {},
				NotificationRead:     {},
			},
		},
	}
}

// SetAuthorizationService sets a process-wide authorization service instance.
func SetAuthorizationService(db *gorm.DB) {
	defaultAuthorizationService = NewAuthorizationService(db)
}

func getAuthorizationService() *AuthorizationService {
	return defaultAuthorizationService
}

func isLedelse(user *models.User) bool {
	if user == nil {
		return false
	}
	return strings.EqualFold(strings.TrimSpace(user.Department.Name), departmentLedelse)
}

func isHR(user *models.User) bool {
	if user == nil {
		return false
	}
	return strings.EqualFold(strings.TrimSpace(user.Department.Name), departmentHR)
}

func isITSupport(user *models.User) bool {
	if user == nil {
		return false
	}
	return strings.EqualFold(strings.TrimSpace(user.Department.Name), departmentITSupport)
}

// HasPermission checks if the user has the given permission.
func HasPermission(user *models.User, permission Permission) bool {
	svc := getAuthorizationService()
	if svc == nil || user == nil {
		return false
	}
	return svc.hasPermission(user, permission)
}

func (a *AuthorizationService) hasPermission(user *models.User, permission Permission) bool {
	if user == nil {
		return false
	}

	if isLedelse(user) {
		return true
	}

	deptName := strings.TrimSpace(user.Department.Name)
	permissions, ok := a.departmentPermissions[deptName]
	if !ok {
		return false
	}

	if _, ok := permissions[AdminFullAccess]; ok {
		return true
	}

	_, ok = permissions[permission]
	return ok
}

// CanAccessTicket checks resource-level access for a ticket.
func CanAccessTicket(user *models.User, ticket *models.Ticket) bool {
	if user == nil || ticket == nil {
		return false
	}
	if isLedelse(user) || isITSupport(user) {
		return true
	}
	if ticket.CreatedByUserId == user.Id {
		return true
	}
	if ticket.AssignedToUserId != nil && *ticket.AssignedToUserId == user.Id {
		return true
	}
	return false
}

// CanAccessAbsenceRequest checks resource-level access for an absence request.
func CanAccessAbsenceRequest(user *models.User, request *models.AbsenceRequest) bool {
	if user == nil || request == nil {
		return false
	}
	if isLedelse(user) {
		return true
	}
	if request.UserId == user.Id {
		return true
	}
	if isHR(user) {
		return true
	}
	return false
}

// CanAccessConversation checks if user can access a conversation.
func CanAccessConversation(user *models.User, conversationID uuid.UUID) bool {
	svc := getAuthorizationService()
	if svc == nil {
		return false
	}
	return svc.CanAccessConversation(context.Background(), user, conversationID)
}

// CanSendMessage checks if user can send a message in a conversation.
func CanSendMessage(user *models.User, conversationID uuid.UUID) bool {
	svc := getAuthorizationService()
	if svc == nil {
		return false
	}
	return svc.CanSendMessage(context.Background(), user, conversationID)
}

// RequirePermission enforces a generic permission.
func RequirePermission(permission Permission) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			svc := getAuthorizationService()
			if svc == nil {
				http.Error(w, "authorization service unavailable", http.StatusInternalServerError)
				return
			}

			r2, user, err := ensureCurrentUserForAuthorization(r, svc.DB)
			if err != nil {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			if !svc.hasPermission(user, permission) {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r2)
		})
	}
}

// RequireTicketAccess enforces ticket resource access without leaking ticket existence.
func RequireTicketAccess() mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			svc := getAuthorizationService()
			if svc == nil {
				http.Error(w, "authorization service unavailable", http.StatusInternalServerError)
				return
			}

			r2, user, err := ensureCurrentUserForAuthorization(r, svc.DB)
			if err != nil {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			if isLedelse(user) {
				next.ServeHTTP(w, r2)
				return
			}

			idRaw := mux.Vars(r)["id"]
			ticketID, err := uuid.Parse(idRaw)
			if err != nil {
				http.Error(w, "invalid UUID: id", http.StatusBadRequest)
				return
			}

			var ticket models.Ticket
			err = svc.DB.WithContext(r.Context()).
				Select("id", "created_by_user_id", "assigned_to_user_id").
				First(&ticket, "id = ?", ticketID).Error
			if err != nil {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}

			if !CanAccessTicket(user, &ticket) {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r2)
		})
	}
}

// RequireConversationAccess enforces conversation access without leaking conversation existence.
func RequireConversationAccess() mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			svc := getAuthorizationService()
			if svc == nil {
				http.Error(w, "authorization service unavailable", http.StatusInternalServerError)
				return
			}

			r2, user, err := ensureCurrentUserForAuthorization(r, svc.DB)
			if err != nil {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			idRaw := mux.Vars(r)["id"]
			conversationID, err := uuid.Parse(idRaw)
			if err != nil {
				http.Error(w, "invalid UUID: id", http.StatusBadRequest)
				return
			}

			if !svc.CanAccessConversation(r.Context(), user, conversationID) {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r2)
		})
	}
}

// CanAccessConversation checks whether user has membership or same department access.
func (a *AuthorizationService) CanAccessConversation(ctx context.Context, user *models.User, conversationID uuid.UUID) bool {
	if a == nil || a.DB == nil || user == nil {
		return false
	}
	if isLedelse(user) {
		return true
	}
	if !a.hasPermission(user, ConversationAccess) {
		return false
	}

	var conversation models.Conversation
	err := a.DB.WithContext(ctx).
		Select("id", "department_id").
		First(&conversation, "id = ?", conversationID).Error
	if err != nil {
		return false
	}

	var count int64
	err = a.DB.WithContext(ctx).
		Model(&models.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", conversationID, user.Id).
		Count(&count).Error
	if err != nil {
		return false
	}

	return count > 0
}

// CanSendMessage checks whether user can send messages in the conversation.
func (a *AuthorizationService) CanSendMessage(ctx context.Context, user *models.User, conversationID uuid.UUID) bool {
	if a == nil || a.DB == nil || user == nil {
		return false
	}
	if isLedelse(user) {
		return true
	}
	if !a.hasPermission(user, MessageSend) {
		return false
	}

	var count int64
	err := a.DB.WithContext(ctx).
		Model(&models.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", conversationID, user.Id).
		Count(&count).Error
	if err != nil {
		return false
	}

	return count > 0
}

func ensureCurrentUserForAuthorization(r *http.Request, db *gorm.DB) (*http.Request, *models.User, error) {
	if existing, ok := r.Context().Value(currentUserContextKey).(*models.User); ok && existing != nil {
		return r, existing, nil
	}

	userIDRaw, ok := GetUserIDFromContext(r.Context())
	if !ok || userIDRaw == "" {
		return r, nil, gorm.ErrRecordNotFound
	}

	userID, err := uuid.Parse(userIDRaw)
	if err != nil {
		return r, nil, err
	}

	var user models.User
	if err := db.WithContext(r.Context()).Preload("Department").First(&user, "id = ?", userID).Error; err != nil {
		return r, nil, err
	}

	ctx := context.WithValue(r.Context(), currentUserContextKey, &user)
	return r.WithContext(ctx), &user, nil
}

func chainWithMiddlewares(handler http.HandlerFunc, middlewares ...mux.MiddlewareFunc) http.Handler {
	var wrapped http.Handler = http.HandlerFunc(handler)
	for i := len(middlewares) - 1; i >= 0; i-- {
		wrapped = middlewares[i](wrapped)
	}
	return wrapped
}
