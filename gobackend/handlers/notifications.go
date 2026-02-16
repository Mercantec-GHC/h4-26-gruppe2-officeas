package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// Notifications holds DB for notification handlers.
type Notifications struct {
	DB *gorm.DB
}

// List godoc
// @Summary      Get notifications for current user
// @Tags         notifications
// @Produce      json
// @Param        unread_only  query  bool  false  "Only unread notifications"
// @Param        limit        query  int   false  "Page size (default 50, max 100)"
// @Param        offset       query  int   false  "Offset (default 0)"
// @Success      200  {array}  models.Notification
// @Failure      401  {string} string "Unauthorized"
// @Security     BearerAuth
// @Router       /notifications [get]
func (h Notifications) List(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	// Keep list endpoints predictable even with bad query input.
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if offset < 0 {
		offset = 0
	}

	unreadOnly, _ := strconv.ParseBool(r.URL.Query().Get("unread_only"))

	query := h.DB.Where("user_id = ?", userID).Order("created_at DESC")
	if unreadOnly {
		query = query.Where("read_at IS NULL")
	}

	var list []models.Notification
	if err := query.Limit(limit).Offset(offset).Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// UnreadCount godoc
// @Summary      Get unread notification count
// @Tags         notifications
// @Produce      json
// @Success      200  {object}  map[string]int64
// @Failure      401  {string} string "Unauthorized"
// @Security     BearerAuth
// @Router       /notifications/unread-count [get]
func (h Notifications) UnreadCount(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var count int64
	if err := h.DB.Model(&models.Notification{}).
		Where("user_id = ? AND read_at IS NULL", userID).
		Count(&count).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]int64{"unread_count": count})
}

// MarkRead godoc
// @Summary      Mark notification as read
// @Tags         notifications
// @Param        id  path  string  true  "Notification ID"
// @Success      204
// @Failure      401  {string} string "Unauthorized"
// @Failure      404  {string} string "notification not found"
// @Security     BearerAuth
// @Router       /notifications/{id}/read [put]
func (h Notifications) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	now := time.Now()
	result := h.DB.Model(&models.Notification{}).
		Where("id = ? AND user_id = ?", id, userID).
		Where("read_at IS NULL").
		Update("read_at", &now)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		// Could already be read — only return 404 if it doesn't belong to this user.
		var existing models.Notification
		if err := h.DB.Where("id = ? AND user_id = ?", id, userID).First(&existing).Error; err != nil {
			http.Error(w, "notification not found", http.StatusNotFound)
			return
		}
	}

	w.WriteHeader(http.StatusNoContent)
}

// MarkUnread godoc
// @Summary      Mark notification as unread
// @Tags         notifications
// @Param        id  path  string  true  "Notification ID"
// @Success      204
// @Failure      401  {string} string "Unauthorized"
// @Failure      404  {string} string "notification not found"
// @Security     BearerAuth
// @Router       /notifications/{id}/unread [put]
func (h Notifications) MarkUnread(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	result := h.DB.Model(&models.Notification{}).
		Where("id = ? AND user_id = ?", id, userID).
		Update("read_at", nil)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		// Could already be unread — verify ownership before deciding it's missing.
		var existing models.Notification
		if err := h.DB.Where("id = ? AND user_id = ?", id, userID).First(&existing).Error; err != nil {
			http.Error(w, "notification not found", http.StatusNotFound)
			return
		}
	}

	w.WriteHeader(http.StatusNoContent)
}

// Delete godoc
// @Summary      Delete notification
// @Tags         notifications
// @Param        id  path  string  true  "Notification ID"
// @Success      204
// @Failure      401  {string} string "Unauthorized"
// @Failure      404  {string} string "notification not found"
// @Security     BearerAuth
// @Router       /notifications/{id} [delete]
func (h Notifications) Delete(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	result := h.DB.Where("id = ? AND user_id = ?", id, userID).Delete(&models.Notification{})
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "notification not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// RegisterNotifications adds notification routes.
func RegisterNotifications(router *mux.Router, h Notifications, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix+"/unread-count", h.UnreadCount).Methods("GET")
	router.HandleFunc(prefix+"/{id}/read", h.MarkRead).Methods("PUT")
	router.HandleFunc(prefix+"/{id}/unread", h.MarkUnread).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}

func createNotification(
	db *gorm.DB,
	userID uuid.UUID,
	title string,
	message string,
	notificationType models.NotificationType,
	relatedEntityID *uuid.UUID,
	relatedEntityType *string,
) {
	n := models.Notification{
		Id:                uuid.New(),
		UserId:            userID,
		Title:             title,
		Message:           message,
		Type:              notificationType,
		CreatedAt:         time.Now(),
		RelatedEntityId:   relatedEntityID,
		RelatedEntityType: relatedEntityType,
	}
	_ = db.Create(&n).Error
}

func createNotifications(
	db *gorm.DB,
	userIDs []uuid.UUID,
	skipUserID *uuid.UUID,
	title string,
	message string,
	notificationType models.NotificationType,
	relatedEntityID *uuid.UUID,
	relatedEntityType *string,
) {
	seen := make(map[uuid.UUID]struct{}, len(userIDs))
	for _, uid := range userIDs {
		if uid == uuid.Nil {
			continue
		}
		if skipUserID != nil && uid == *skipUserID {
			continue
		}
		if _, exists := seen[uid]; exists {
			continue
		}
		// Same user can come from multiple sources; only create one row.
		seen[uid] = struct{}{}
		createNotification(db, uid, title, message, notificationType, relatedEntityID, relatedEntityType)
	}
}
