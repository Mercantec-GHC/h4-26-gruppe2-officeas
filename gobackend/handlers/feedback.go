package handlers

import (
	"encoding/json"
	"net/http"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// Feedback holds DB for feedback handlers
type Feedback struct {
	DB *gorm.DB
}

// List godoc
// @Summary      Get all feedback
// @Tags         feedback
// @Produce      json
// @Success      200  {array}   models.Feedback
// @Router       /feedback [get]
func (h Feedback) List(w http.ResponseWriter, r *http.Request) {
	var list []models.Feedback

	if err := h.DB.Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// GetByID godoc
// @Summary      Get feedback by ID
// @Tags         feedback
// @Produce      json
// @Param        id   path      string  true  "Feedback ID"
// @Success      200  {object}  models.Feedback
// @Failure      404  {string}  string  "Feedback not found"
// @Router       /feedback/{id} [get]
func (h Feedback) GetByID(w http.ResponseWriter, r *http.Request) {
	id := mux.Vars(r)["id"]
	var feedback models.Feedback

	if err := h.DB.First(&feedback, "id = ?", id).Error; err != nil {
		http.Error(w, "Feedback not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(feedback)
}

// Create godoc
// @Summary      Create a new feedback
// @Tags         feedback
// @Accept       json
// @Produce      json
// @Param        feedback  body      models.Feedback  true  "Feedback"
// @Success      201  {object}  models.Feedback
// @Failure      400  {string}  string  "Bad request"
// @Router       /feedback [post]
func (h Feedback) Create(w http.ResponseWriter, r *http.Request) {
	var f models.Feedback

	if err := json.NewDecoder(r.Body).Decode(&f); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	f.Id = uuid.New()

	if err := h.DB.Create(&f).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(f)
}

// Update godoc
// @Summary      Update feedback by ID
// @Tags         feedback
// @Accept       json
// @Produce      json
// @Param        id        path      string  true  "Feedback ID"
// @Param        feedback  body      models.Feedback  true  "Feedback"
// @Success      200  {object}  models.Feedback
// @Failure      404  {string}  string  "Feedback not found"
// @Router       /feedback/{id} [put]
func (h Feedback) Update(w http.ResponseWriter, r *http.Request) {
	id := mux.Vars(r)["id"]
	var feedback models.Feedback

	if err := h.DB.First(&feedback, "id = ?", id).Error; err != nil {
		http.Error(w, "Feedback not found", http.StatusNotFound)
		return
	}

	if err := json.NewDecoder(r.Body).Decode(&feedback); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	feedback.Id, _ = uuid.Parse(id)

	h.DB.Save(&feedback)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(feedback)
}

// Delete godoc
// @Summary      Delete feedback by ID
// @Tags         feedback
// @Param        id   path      string  true  "Feedback ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "Feedback not found"
// @Router       /feedback/{id} [delete]
func (h Feedback) Delete(w http.ResponseWriter, r *http.Request) {
	id := mux.Vars(r)["id"]

	result := h.DB.Delete(&models.Feedback{}, "id = ?", id)
	if result.RowsAffected == 0 {
		http.Error(w, "Feedback not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// RegisterFeedback adds feedback routes
func RegisterFeedback(router *mux.Router, h Feedback, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
