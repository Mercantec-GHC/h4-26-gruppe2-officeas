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

// AbsenceRequests holds DB for absence request handlers
type AbsenceRequests struct {
	DB *gorm.DB
}

// List godoc
// @Summary      Get all absence requests
// @Tags         absence-requests
// @Produce      json
// @Success      200  {array}   models.AbsenceRequest
// @Security     BearerAuth
// @Router       /absence-requests [get]
func (h AbsenceRequests) List(w http.ResponseWriter, r *http.Request) {
	var list []models.AbsenceRequest
	
	if err := h.DB.Preload("User").Preload("ReviewedByUser").Preload("Comments").Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// GetByID godoc
// @Summary      Get absence request by ID
// @Tags         absence-requests
// @Produce      json
// @Param        id   path      string  true  "Absence Request ID"
// @Success      200  {object}  models.AbsenceRequest
// @Failure      404  {string}  string  "absence request not found"
// @Security     BearerAuth
// @Router       /absence-requests/{id} [get]
func (h AbsenceRequests) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var a models.AbsenceRequest
	
	if err := h.DB.Preload("User").Preload("ReviewedByUser").Preload("Comments").First(&a, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "absence request not found", http.StatusNotFound)
			return
		}
	
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(a)
}

// Create godoc
// @Summary      Create a new absence request
// @Tags         absence-requests
// @Accept       json
// @Produce      json
// @Param        absenceRequest  body      models.AbsenceRequest  true  "Absence Request"
// @Success      201  {object}  models.AbsenceRequest
// @Failure      400  {string}  string  "Bad request"
// @Security     BearerAuth
// @Router       /absence-requests [post]
func (h AbsenceRequests) Create(w http.ResponseWriter, r *http.Request) {
	var a models.AbsenceRequest
	
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	a.Id = uuid.New()
	
	if a.Status == "" {
		a.Status = models.RequestStatusPending
	}
	
	if err := h.DB.Create(&a).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(a)
}

// Update godoc
// @Summary      Update absence request by ID
// @Tags         absence-requests
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "Absence Request ID"
// @Param        absenceRequest  body      models.AbsenceRequest  true  "Absence Request"
// @Success      200  {object}  models.AbsenceRequest
// @Failure      404  {string}  string  "absence request not found"
// @Security     BearerAuth
// @Router       /absence-requests/{id} [put]
func (h AbsenceRequests) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var a models.AbsenceRequest
	
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	a.Id = id
	
	updates := map[string]interface{}{
		"user_id":     a.UserId,
		"type":        a.Type,
		"start_date":  a.StartDate,
		"end_date":    a.EndDate,
		"shift_id":    a.ShiftId,
		"status":      a.Status,
		"reviewed_by_user_id": a.ReviewedByUserId,
	}
	
	if a.Status == models.RequestStatusApproved || a.Status == models.RequestStatusRejected {
		now := time.Now()
		updates["reviewed_at"] = &now
	}
	
	result := h.DB.Model(&models.AbsenceRequest{}).Where("id = ?", id).Updates(updates)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "absence request not found", http.StatusNotFound)
		return
	}
	
	h.DB.Preload("User").Preload("ReviewedByUser").Preload("Comments").First(&a, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(a)
}

// Delete godoc
// @Summary      Delete absence request by ID
// @Tags         absence-requests
// @Param        id   path      string  true  "Absence Request ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "absence request not found"
// @Security     BearerAuth
// @Router       /absence-requests/{id} [delete]
func (h AbsenceRequests) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	result := h.DB.Delete(&models.AbsenceRequest{}, "id = ?", id)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "absence request not found", http.StatusNotFound)
		return
	}
	
	w.WriteHeader(http.StatusNoContent)
}

// Approve godoc
// @Summary      Approve an absence request
// @Tags         absence-requests
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "Absence Request ID"
// @Param        body  body      object  false  "Reviewer ID (optional)"  SchemaExample({"reviewed_by_user_id": "uuid"})
// @Success      200  {object}  models.AbsenceRequest
// @Failure      404  {string}  string  "absence request not found"
// @Security     BearerAuth
// @Router       /absence-requests/{id}/approve [put]
func (h AbsenceRequests) Approve(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	// Check if request exists
	var a models.AbsenceRequest
	
	if err := h.DB.First(&a, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "absence request not found", http.StatusNotFound)
			return
		}
		
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	// Parse optional reviewed_by_user_id from body
	var body struct {
		ReviewedByUserId *uuid.UUID `json:"reviewed_by_user_id"`
	}
	
	// Body is optional, so ignore decode errors
	_ = json.NewDecoder(r.Body).Decode(&body)
	
	now := time.Now()
	updates := map[string]interface{}{
		"status":      models.RequestStatusApproved,
		"reviewed_at": &now,
	}
	
	if body.ReviewedByUserId != nil {
		updates["reviewed_by_user_id"] = body.ReviewedByUserId
	}
	
	result := h.DB.Model(&models.AbsenceRequest{}).Where("id = ?", id).Updates(updates)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "absence request not found", http.StatusNotFound)
		return
	}
	
	h.DB.Preload("User").Preload("ReviewedByUser").Preload("Comments").First(&a, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(a)
}

// RegisterAbsenceRequests adds absence request routes
func RegisterAbsenceRequests(router *mux.Router, h AbsenceRequests, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}/approve", h.Approve).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
