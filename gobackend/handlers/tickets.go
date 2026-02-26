package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// Tickets holds DB for ticket handlers
type Tickets struct {
	DB *gorm.DB
}

// List godoc
// @Summary      Get all tickets
// @Tags         tickets
// @Produce      json
// @Success      200  {array}   models.Ticket
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /tickets [get]
func (h Tickets) List(w http.ResponseWriter, r *http.Request) {
	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var list []models.Ticket
	query := h.DB.WithContext(r.Context()).Preload("CreatedByUser").Preload("AssignedToUser").Preload("Comments")

	if !isLedelse(currentUser) && !isITSupport(currentUser) {
		query = query.Where("created_by_user_id = ? OR assigned_to_user_id = ?", currentUser.Id, currentUser.Id)
	}

	if err := query.Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// GetByID godoc
// @Summary      Get ticket by ID
// @Tags         tickets
// @Produce      json
// @Param        id   path      string  true  "Ticket ID"
// @Success      200  {object}  models.Ticket
// @Failure      404  {string}  string  "ticket not found"
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /tickets/{id} [get]
func (h Tickets) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	var t models.Ticket

	if err := h.DB.Preload("CreatedByUser").Preload("AssignedToUser").Preload("Comments").First(&t, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "ticket not found", http.StatusNotFound)
			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(t)
}

// Create godoc
// @Summary      Create a new ticket
// @Tags         tickets
// @Accept       json
// @Produce      json
// @Param        ticket  body      models.Ticket  true  "Ticket"
// @Success      201  {object}  models.Ticket
// @Failure      400  {string}  string  "Bad request"
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /tickets [post]
func (h Tickets) Create(w http.ResponseWriter, r *http.Request) {
	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var t models.Ticket

	if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if t.AssignedToUserId != nil && !HasPermission(currentUser, TicketAssign) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	t.Id = uuid.New()
	t.CreatedByUserId = currentUser.Id

	if t.Status == "" {
		t.Status = models.TicketStatusOpen
	}

	if err := h.DB.WithContext(r.Context()).Create(&t).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if t.AssignedToUserId != nil {
		relatedType := "ticket"
		createNotification(
			h.DB,
			*t.AssignedToUserId,
			"Ticket assigned",
			"You were assigned to ticket: "+t.Title,
			models.NotificationTypeTicketAssigned,
			&t.Id,
			&relatedType,
		)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(t)
}

// Update godoc
// @Summary      Update ticket by ID
// @Tags         tickets
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "Ticket ID"
// @Param        ticket  body      models.Ticket  true  "Ticket"
// @Success      200  {object}  models.Ticket
// @Failure      404  {string}  string  "ticket not found"
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /tickets/{id} [put]
func (h Tickets) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var existing models.Ticket
	if err := h.DB.WithContext(r.Context()).First(&existing, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "ticket not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var t models.Ticket

	if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	t.Id = id

	isCreator := existing.CreatedByUserId == currentUser.Id
	isAssignee := existing.AssignedToUserId != nil && *existing.AssignedToUserId == currentUser.Id
	canManage := isLedelse(currentUser) || isITSupport(currentUser)

	if !canManage && !isCreator && !isAssignee {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	if !canManage {
		if t.AssignedToUserId != nil {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		if isAssignee && !isCreator {
			if t.Status != models.TicketStatusResolved && t.Status != models.TicketStatusClosed {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}

			if t.Title != "" || t.Description != "" {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
		}
	}

	// Build updates from existing; only overwrite with body values when present (avoid writing zero values)
	updates := map[string]interface{}{
		"title":               existing.Title,
		"description":         existing.Description,
		"status":              existing.Status,
		"assigned_to_user_id": existing.AssignedToUserId,
	}

	if canManage || isCreator {
		if t.Title != "" {
			updates["title"] = t.Title
		}
		
		if t.Description != "" {
			updates["description"] = t.Description
		}
	}

	if canManage {
		updates["assigned_to_user_id"] = t.AssignedToUserId
	}
	if t.Status != "" {
		updates["status"] = t.Status
	}

	if t.Status == models.TicketStatusResolved || t.Status == models.TicketStatusClosed {
		now := time.Now()
		updates["resolved_at"] = &now
	}

	result := h.DB.WithContext(r.Context()).Model(&models.Ticket{}).Where("id = ?", id).Updates(updates)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "ticket not found", http.StatusNotFound)
		return
	}

	h.DB.WithContext(r.Context()).Preload("CreatedByUser").Preload("AssignedToUser").Preload("Comments").First(&t, "id = ?", id)

	relatedType := "ticket"
	if t.AssignedToUserId != nil {
		if existing.AssignedToUserId == nil || *existing.AssignedToUserId != *t.AssignedToUserId {
			createNotification(
				h.DB,
				*t.AssignedToUserId,
				"Ticket assigned",
				"You were assigned to ticket: "+t.Title,
				models.NotificationTypeTicketAssigned,
				&t.Id,
				&relatedType,
			)
		} else {
			createNotification(
				h.DB,
				*t.AssignedToUserId,
				"Ticket updated",
				"Ticket was updated: "+t.Title,
				models.NotificationTypeTicketUpdated,
				&t.Id,
				&relatedType,
			)
		}
	}

	if t.CreatedByUserId != uuid.Nil && (t.AssignedToUserId == nil || t.CreatedByUserId != *t.AssignedToUserId) {
		createNotification(
			h.DB,
			t.CreatedByUserId,
			"Ticket updated",
			"Ticket was updated: "+t.Title,
			models.NotificationTypeTicketUpdated,
			&t.Id,
			&relatedType,
		)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(t)
}

// Delete godoc
// @Summary      Delete ticket by ID
// @Tags         tickets
// @Param        id   path      string  true  "Ticket ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "ticket not found"
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /tickets/{id} [delete]
func (h Tickets) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if !isLedelse(currentUser) && !isITSupport(currentUser) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	// Delete comments first (no CASCADE on the model), then the ticket
	if err := h.DB.Where("ticket_id = ?", id).Delete(&models.TicketComment{}).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	result := h.DB.Delete(&models.Ticket{}, "id = ?", id)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "ticket not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// RegisterTickets adds ticket routes
func RegisterTickets(router *mux.Router, h Tickets, prefix string) {
	router.Handle(prefix, chainWithMiddlewares(h.List, RequirePermission(TicketView))).Methods("GET")
	router.Handle(prefix, chainWithMiddlewares(h.Create, RequirePermission(TicketCreate))).Methods("POST")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.GetByID, RequireTicketAccess())).Methods("GET")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.Update, RequireTicketAccess())).Methods("PUT")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.Delete, RequireTicketAccess())).Methods("DELETE")
}
