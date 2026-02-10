package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"

	"stuff/internal/messaging"
	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
)

// Messaging handles HTTP requests for the messaging module.
// All business logic lives in messaging.Service.
type Messaging struct {
	Service *messaging.Service
	Hub     *messaging.Hub
}

// allowedWSOrigins lists production origins permitted for WebSocket connections.
var allowedWSOrigins = map[string]bool{
	"https://h4-flutter.mercantec.tech": true,
	"https://h4-api.mercantec.tech":     true,
}

// upgrader configures the WebSocket upgrader with origin checking.
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		// Allow requests with no Origin header (e.g. native mobile apps)
		if origin == "" {
			return true
		}
		if allowedWSOrigins[origin] {
			return true
		}
		// Allow any localhost port (Flutter web debug uses a random port)
		return strings.HasPrefix(origin, "http://localhost:") ||
			strings.HasPrefix(origin, "http://127.0.0.1:")
	},
}

// ---------------------------------------------------------------------------
// POST /conversations — Create a new conversation
// ---------------------------------------------------------------------------

// CreateConversation godoc
// @Summary      Create a new conversation
// @Description  Creates a new conversation among the specified users within the caller's department
// @Tags         messaging
// @Accept       json
// @Produce      json
// @Param        body  body  models.CreateConversationRequest  true  "Conversation details"
// @Success      201  {object}  models.ConversationDTO
// @Failure      400  {string}  string  "Invalid request"
// @Failure      401  {string}  string  "Unauthorized"
// @Failure      403  {string}  string  "Forbidden"
// @Security     BearerAuth
// @Router       /conversations [post]
func (h Messaging) CreateConversation(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req models.CreateConversationRequest
	r.Body = http.MaxBytesReader(w, r.Body, 1<<16) // 64 KB max
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if len(req.UserIDs) < 2 {
		http.Error(w, "a conversation needs at least 2 members", http.StatusBadRequest)
		return
	}

	// Look up the caller's department to scope the conversation.
	departmentID, err := h.Service.GetUserDepartmentID(userID)
	if err != nil {
		http.Error(w, "could not determine department", http.StatusInternalServerError)
		return
	}

	conv, err := h.Service.CreateConversation(userID, departmentID, req.UserIDs, req.IsGroup)
	if err != nil {
		mapServiceError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(conv)
}

// ---------------------------------------------------------------------------
// GET /conversations — List conversations for the current user
// ---------------------------------------------------------------------------

// ListConversations godoc
// @Summary      List conversations
// @Description  Returns all conversations the current user is a member of
// @Tags         messaging
// @Produce      json
// @Success      200  {array}   models.ConversationDTO
// @Failure      401  {string}  string  "Unauthorized"
// @Security     BearerAuth
// @Router       /conversations [get]
func (h Messaging) ListConversations(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	convs, err := h.Service.GetConversations(userID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(convs)
}

// ---------------------------------------------------------------------------
// POST /conversations/{id}/messages — Send a message
// ---------------------------------------------------------------------------

// SendMessage godoc
// @Summary      Send a message
// @Description  Sends an encrypted message to the specified conversation
// @Tags         messaging
// @Accept       json
// @Produce      json
// @Param        id    path  string                    true  "Conversation ID"
// @Param        body  body  models.SendMessageRequest  true  "Message content"
// @Success      201  {object}  models.MessageDTO
// @Failure      400  {string}  string  "Invalid request"
// @Failure      401  {string}  string  "Unauthorized"
// @Failure      403  {string}  string  "Not a member"
// @Failure      429  {string}  string  "Rate limit exceeded"
// @Security     BearerAuth
// @Router       /conversations/{id}/messages [post]
func (h Messaging) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	convID, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	var req models.SendMessageRequest
	r.Body = http.MaxBytesReader(w, r.Body, 1<<16) // 64 KB max
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	msg, err := h.Service.SendMessage(userID, convID, req.Content)
	if err != nil {
		mapServiceError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(msg)
}

// ---------------------------------------------------------------------------
// GET /conversations/{id}/messages — Get messages (paginated)
// ---------------------------------------------------------------------------

// GetMessages godoc
// @Summary      Get messages
// @Description  Returns paginated messages for the specified conversation (newest first)
// @Tags         messaging
// @Produce      json
// @Param        id      path   string  true   "Conversation ID"
// @Param        limit   query  int     false  "Page size (max 100, default 50)"
// @Param        offset  query  int     false  "Offset (default 0)"
// @Success      200  {object}  models.PaginatedMessages
// @Failure      401  {string}  string  "Unauthorized"
// @Failure      403  {string}  string  "Not a member"
// @Security     BearerAuth
// @Router       /conversations/{id}/messages [get]
func (h Messaging) GetMessages(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	convID, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	result, err := h.Service.GetMessages(userID, convID, limit, offset)
	if err != nil {
		mapServiceError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// ---------------------------------------------------------------------------
// PUT /messages/{id}/read — Mark a message as read
// ---------------------------------------------------------------------------

// MarkAsRead godoc
// @Summary      Mark message as read
// @Description  Sets the read timestamp on a message for the current user
// @Tags         messaging
// @Param        id  path  string  true  "Message ID"
// @Success      204  "No Content"
// @Failure      401  {string}  string  "Unauthorized"
// @Failure      403  {string}  string  "Not a member"
// @Failure      404  {string}  string  "Message not found"
// @Security     BearerAuth
// @Router       /messages/{id}/read [put]
func (h Messaging) MarkAsRead(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	msgID, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	if err := h.Service.MarkAsRead(userID, msgID); err != nil {
		mapServiceError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------------------
// GET /conversations/{id}/unread — Get unread message count
// ---------------------------------------------------------------------------

// GetUnreadCount godoc
// @Summary      Get unread message count
// @Description  Returns the number of unread messages in a conversation for the current user
// @Tags         messaging
// @Produce      json
// @Param        id  path  string  true  "Conversation ID"
// @Success      200  {object}  map[string]int64
// @Failure      401  {string}  string  "Unauthorized"
// @Failure      403  {string}  string  "Not a member"
// @Security     BearerAuth
// @Router       /conversations/{id}/unread [get]
func (h Messaging) GetUnreadCount(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	convID, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	count, err := h.Service.GetUnreadCount(userID, convID)
	if err != nil {
		mapServiceError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]int64{"unread_count": count})
}

// ---------------------------------------------------------------------------
// GET /ws/messages — WebSocket endpoint
// ---------------------------------------------------------------------------

// WebSocket godoc
// @Summary      WebSocket messaging endpoint
// @Description  Upgrades to WebSocket. Requires JWT in query param ?token=...
// @Tags         messaging
// @Param        token  query  string  true  "JWT token"
// @Success      101    "Switching Protocols"
// @Failure      401    {string}  string  "Unauthorized"
// @Router       /ws/messages [get]
func (h Messaging) WebSocket(w http.ResponseWriter, r *http.Request) {
	// Authenticate via query param (browsers can't send custom headers on WS upgrade).
	tokenStr := r.URL.Query().Get("token")
	if tokenStr == "" {
		http.Error(w, "token query parameter required", http.StatusUnauthorized)
		return
	}

	userID, err := parseJWTUserID(tokenStr)
	if err != nil {
		http.Error(w, "invalid token", http.StatusUnauthorized)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WS] upgrade failed for user=%s: %v", userID, err)
		return
	}

	client := h.Hub.NewClient(userID, conn)
	h.Hub.RegisterClient(client)
	messaging.StartClient(client)
}

// ---------------------------------------------------------------------------
// Route Registration
// ---------------------------------------------------------------------------

// RegisterMessaging registers all messaging routes.
func RegisterMessaging(protectedRouter *mux.Router, rawRouter *mux.Router, h Messaging) {
	// REST endpoints (protected by AuthMiddleware on protectedRouter)
	protectedRouter.HandleFunc("/conversations", h.CreateConversation).Methods("POST")
	protectedRouter.HandleFunc("/conversations", h.ListConversations).Methods("GET")
	protectedRouter.HandleFunc("/conversations/{id}/messages", h.SendMessage).Methods("POST")
	protectedRouter.HandleFunc("/conversations/{id}/messages", h.GetMessages).Methods("GET")
	protectedRouter.HandleFunc("/conversations/{id}/unread", h.GetUnreadCount).Methods("GET")
	protectedRouter.HandleFunc("/messages/{id}/read", h.MarkAsRead).Methods("PUT")

	// WebSocket endpoint on the raw router (JWT verified inside handler)
	rawRouter.HandleFunc("/ws/messages", h.WebSocket).Methods("GET")
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// currentUserUUID extracts the user ID set by AuthMiddleware.
func currentUserUUID(r *http.Request) (uuid.UUID, error) {
	idStr, ok := GetUserIDFromContext(r.Context())
	if !ok {
		return uuid.Nil, http.ErrNoCookie // any non-nil error
	}
	return uuid.Parse(idStr)
}

// serviceErrorStatus maps service errors to HTTP status codes.
var serviceErrorStatus = map[error]int{
	messaging.ErrNotMember:       http.StatusForbidden,
	messaging.ErrWrongDepartment: http.StatusForbidden,
	messaging.ErrMessageTooLong:  http.StatusBadRequest,
	messaging.ErrEmptyMessage:    http.StatusBadRequest,
	messaging.ErrMessageNotFound: http.StatusNotFound,
	messaging.ErrConvNotFound:    http.StatusNotFound,
	messaging.ErrRateLimited:     http.StatusTooManyRequests,
}

// mapServiceError turns a service error into an HTTP error response.
func mapServiceError(w http.ResponseWriter, err error) {
	if code, ok := serviceErrorStatus[err]; ok {
		if err == messaging.ErrRateLimited {
			w.Header().Set("Retry-After", "5")
		}
		http.Error(w, err.Error(), code)
		return
	}
	http.Error(w, "internal server error", http.StatusInternalServerError)
}

// parseJWTUserID validates a JWT and returns the user ID.
func parseJWTUserID(tokenStr string) (uuid.UUID, error) {
	token, err := parseAndValidateJWT(tokenStr)
	if err != nil {
		return uuid.Nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok {
		return uuid.Nil, http.ErrNoCookie
	}
	return uuid.Parse(claims.UserID)
}
