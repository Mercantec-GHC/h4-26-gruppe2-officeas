package handlers

import (
	"encoding/json"
	"net/http"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// TicketComments holds DB for ticket comment handlers
type TicketComments struct {
	DB *gorm.DB
}

// ListByTicket godoc
// @Summary      Get all comments for a ticket
// @Tags         ticket-comments
// @Produce      json
// @Param        ticketId   path      string  true  "Ticket ID"
// @Success      200  {array}   models.TicketComment
// @Security     BearerAuth
// @Router       /tickets/{ticketId}/comments [get]
func (h TicketComments) ListByTicket(w http.ResponseWriter, r *http.Request) {
	ticketId, ok := uuidParam(w, r, "ticketId")

	if !ok {
		return
	}

	var list []models.TicketComment

	if err := h.DB.Preload("User").Where("ticket_id = ?", ticketId).Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// CreateOnTicket godoc
// @Summary      Create a comment on a ticket
// @Tags         ticket-comments
// @Accept       json
// @Produce      json
// @Param        ticketId   path      string  true  "Ticket ID"
// @Param        comment  body      models.TicketComment  true  "Ticket Comment"
// @Success      201  {object}  models.TicketComment
// @Failure      400  {string}  string  "Bad request"
// @Security     BearerAuth
// @Router       /tickets/{ticketId}/comments [post]
func (h TicketComments) CreateOnTicket(w http.ResponseWriter, r *http.Request) {
	ticketId, ok := uuidParam(w, r, "ticketId")

	if !ok {
		return
	}

	var c models.TicketComment

	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	c.Id = uuid.New()
	c.TicketId = ticketId

	if err := h.DB.Create(&c).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var ticket models.Ticket
	if err := h.DB.First(&ticket, "id = ?", ticketId).Error; err == nil {
		relatedType := "ticket"
		userIDs := []uuid.UUID{ticket.CreatedByUserId}
		if ticket.AssignedToUserId != nil {
			userIDs = append(userIDs, *ticket.AssignedToUserId)
		}
		createNotifications(
			h.DB,
			userIDs,
			&c.UserId,
			"New ticket comment",
			"A new comment was added to ticket: "+ticket.Title,
			models.NotificationTypeTicketCommented,
			&ticketId,
			&relatedType,
		)
	}

	h.DB.Preload("User").Preload("Ticket").First(&c, "id = ?", c.Id)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(c)
}

// GetByID godoc
// @Summary      Get ticket comment by ID
// @Tags         ticket-comments
// @Produce      json
// @Param        id   path      string  true  "Ticket Comment ID"
// @Success      200  {object}  models.TicketComment
// @Failure      404  {string}  string  "ticket comment not found"
// @Security     BearerAuth
// @Router       /ticket-comments/{id} [get]
func (h TicketComments) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	var c models.TicketComment

	if err := h.DB.Preload("User").Preload("Ticket").First(&c, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "ticket comment not found", http.StatusNotFound)
			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(c)
}

// Update godoc
// @Summary      Update ticket comment by ID
// @Tags         ticket-comments
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "Ticket Comment ID"
// @Param        comment  body      models.TicketComment  true  "Ticket Comment"
// @Success      200  {object}  models.TicketComment
// @Failure      404  {string}  string  "ticket comment not found"
// @Security     BearerAuth
// @Router       /ticket-comments/{id} [put]
func (h TicketComments) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	var c models.TicketComment

	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	c.Id = id
	result := h.DB.Model(&models.TicketComment{}).Where("id = ?", id).Update("content", c.Content)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "ticket comment not found", http.StatusNotFound)
		return
	}

	h.DB.Preload("User").Preload("Ticket").First(&c, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(c)
}

// Delete godoc
// @Summary      Delete ticket comment by ID
// @Tags         ticket-comments
// @Param        id   path      string  true  "Ticket Comment ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "ticket comment not found"
// @Security     BearerAuth
// @Router       /ticket-comments/{id} [delete]
func (h TicketComments) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	result := h.DB.Delete(&models.TicketComment{}, "id = ?", id)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "ticket comment not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// RegisterTicketComments adds ticket comment routes (nested under tickets + standalone by id)
func RegisterTicketComments(router *mux.Router, h TicketComments, ticketsPrefix, commentsPrefix string) {
	router.Handle(ticketsPrefix+"/{ticketId}/comments", chainWithMiddlewares(h.ListByTicket, RequirePermission(TicketView))).Methods("GET")
	router.Handle(ticketsPrefix+"/{ticketId}/comments", chainWithMiddlewares(h.CreateOnTicket, RequirePermission(TicketView))).Methods("POST")
	router.Handle(commentsPrefix+"/{id}", chainWithMiddlewares(h.GetByID, RequirePermission(TicketView))).Methods("GET")
	router.Handle(commentsPrefix+"/{id}", chainWithMiddlewares(h.Update, RequirePermission(TicketView))).Methods("PUT")
	router.Handle(commentsPrefix+"/{id}", chainWithMiddlewares(h.Delete, RequirePermission(TicketView))).Methods("DELETE")
}
