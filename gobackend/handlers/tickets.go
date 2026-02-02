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
	var list []models.Ticket
	
	if err := h.DB.Preload("CreatedByUser").Preload("AssignedToUser").Preload("Comments").Find(&list).Error; err != nil {
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
	var t models.Ticket
	
	if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	t.Id = uuid.New()
	
	if t.Status == "" {
		t.Status = models.TicketStatusOpen
	}
	
	if err := h.DB.Create(&t).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
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
	
	var t models.Ticket
	
	if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	t.Id = id
	
	updates := map[string]interface{}{
		"title":                 t.Title,
		"description":           t.Description,
		"status":                t.Status,
		"assigned_to_user_id":   t.AssignedToUserId,
	}
	
	if t.Status == models.TicketStatusResolved || t.Status == models.TicketStatusClosed {
		now := time.Now()
		updates["resolved_at"] = &now
	}
	
	result := h.DB.Model(&models.Ticket{}).Where("id = ?", id).Updates(updates)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "ticket not found", http.StatusNotFound)
		return
	}
	
	h.DB.Preload("CreatedByUser").Preload("AssignedToUser").Preload("Comments").First(&t, "id = ?", id)
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
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
