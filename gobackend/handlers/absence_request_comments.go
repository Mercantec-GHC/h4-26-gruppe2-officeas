package handlers

import (
	"encoding/json"
	"net/http"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// AbsenceRequestComments holds DB for absence request comment handlers
type AbsenceRequestComments struct {
	DB *gorm.DB
}

// ListByAbsenceRequest godoc
// @Summary      Get all comments for an absence request
// @Tags         absence-request-comments
// @Produce      json
// @Param        absenceRequestId   path      string  true  "Absence Request ID"
// @Success      200  {array}   models.AbsenceRequestComment
// @Router       /absence-requests/{absenceRequestId}/comments [get]
func (h AbsenceRequestComments) ListByAbsenceRequest(w http.ResponseWriter, r *http.Request) {
	absenceRequestId, ok := uuidParam(w, r, "absenceRequestId")

	if !ok {
		return
	}
	
	var list []models.AbsenceRequestComment
	
	if err := h.DB.Preload("User").Where("absence_request_id = ?", absenceRequestId).Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// CreateOnAbsenceRequest godoc
// @Summary      Create a comment on an absence request
// @Tags         absence-request-comments
// @Accept       json
// @Produce      json
// @Param        absenceRequestId   path      string  true  "Absence Request ID"
// @Param        comment  body      models.AbsenceRequestComment  true  "Absence Request Comment"
// @Success      201  {object}  models.AbsenceRequestComment
// @Failure      400  {string}  string  "Bad request"
// @Router       /absence-requests/{absenceRequestId}/comments [post]
func (h AbsenceRequestComments) CreateOnAbsenceRequest(w http.ResponseWriter, r *http.Request) {
	absenceRequestId, ok := uuidParam(w, r, "absenceRequestId")
	
	if !ok {
		return
	}
	
	var c models.AbsenceRequestComment
	
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	c.Id = uuid.New()
	c.AbsenceRequestId = absenceRequestId
	
	if err := h.DB.Create(&c).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	h.DB.Preload("User").Preload("AbsenceRequest").First(&c, "id = ?", c.Id)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(c)
}

// GetByID godoc
// @Summary      Get absence request comment by ID
// @Tags         absence-request-comments
// @Produce      json
// @Param        id   path      string  true  "Absence Request Comment ID"
// @Success      200  {object}  models.AbsenceRequestComment
// @Failure      404  {string}  string  "absence request comment not found"
// @Router       /absence-request-comments/{id} [get]
func (h AbsenceRequestComments) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var c models.AbsenceRequestComment
	
	if err := h.DB.Preload("User").Preload("AbsenceRequest").First(&c, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "absence request comment not found", http.StatusNotFound)
			return
		}
	
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(c)
}

// Update godoc
// @Summary      Update absence request comment by ID
// @Tags         absence-request-comments
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "Absence Request Comment ID"
// @Param        comment  body      models.AbsenceRequestComment  true  "Absence Request Comment"
// @Success      200  {object}  models.AbsenceRequestComment
// @Failure      404  {string}  string  "absence request comment not found"
// @Router       /absence-request-comments/{id} [put]
func (h AbsenceRequestComments) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var c models.AbsenceRequestComment
	
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	c.Id = id
	result := h.DB.Model(&models.AbsenceRequestComment{}).Where("id = ?", id).Update("content", c.Content)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "absence request comment not found", http.StatusNotFound)
		return
	}
	
	h.DB.Preload("User").Preload("AbsenceRequest").First(&c, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(c)
}

// Delete godoc
// @Summary      Delete absence request comment by ID
// @Tags         absence-request-comments
// @Param        id   path      string  true  "Absence Request Comment ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "absence request comment not found"
// @Router       /absence-request-comments/{id} [delete]
func (h AbsenceRequestComments) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}
	
	result := h.DB.Delete(&models.AbsenceRequestComment{}, "id = ?", id)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "absence request comment not found", http.StatusNotFound)
		return
	}
	
	w.WriteHeader(http.StatusNoContent)
}

// RegisterAbsenceRequestComments adds absence request comment routes
func RegisterAbsenceRequestComments(router *mux.Router, h AbsenceRequestComments, absenceRequestsPrefix, commentsPrefix string) {
	router.HandleFunc(absenceRequestsPrefix+"/{absenceRequestId}/comments", h.ListByAbsenceRequest).Methods("GET")
	router.HandleFunc(absenceRequestsPrefix+"/{absenceRequestId}/comments", h.CreateOnAbsenceRequest).Methods("POST")
	router.HandleFunc(commentsPrefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(commentsPrefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(commentsPrefix+"/{id}", h.Delete).Methods("DELETE")
}
