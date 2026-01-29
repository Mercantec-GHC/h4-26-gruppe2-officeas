package handlers

import (
	"encoding/json"
	"net/http"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// Shifts holds DB for shift handlers
type Shifts struct {
	DB *gorm.DB
}

// List godoc
// @Summary      Get all shifts
// @Tags         shifts
// @Produce      json
// @Success      200  {array}   models.Shift
// @Router       /shifts [get]
func (h Shifts) List(w http.ResponseWriter, r *http.Request) {
	var list []models.Shift

	if err := h.DB.Preload("User").Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// GetByID godoc
// @Summary      Get shift by ID
// @Tags         shifts
// @Produce      json
// @Param        id   path      string  true  "Shift ID"
// @Success      200  {object}  models.Shift
// @Failure      404  {string}  string  "shift not found"
// @Router       /shifts/{id} [get]
func (h Shifts) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var s models.Shift
	
	if err := h.DB.Preload("User").First(&s, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "shift not found", http.StatusNotFound)
			return
		}
	
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(s)
}

// Create godoc
// @Summary      Create a new shift
// @Tags         shifts
// @Accept       json
// @Produce      json
// @Param        shift  body      models.Shift  true  "Shift"
// @Success      201  {object}  models.Shift
// @Failure      400  {string}  string  "Bad request"
// @Router       /shifts [post]
func (h Shifts) Create(w http.ResponseWriter, r *http.Request) {
	var s models.Shift
	
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	s.Id = uuid.New()
	
	if err := h.DB.Create(&s).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(s)
}

// Update godoc
// @Summary      Update shift by ID
// @Tags         shifts
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "Shift ID"
// @Param        shift  body      models.Shift  true  "Shift"
// @Success      200  {object}  models.Shift
// @Failure      404  {string}  string  "shift not found"
// @Router       /shifts/{id} [put]
func (h Shifts) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var s models.Shift
	
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	s.Id = id
	
	result := h.DB.Model(&models.Shift{}).Where("id = ?", id).Updates(map[string]interface{}{
		"user_id":    s.UserId,
		"start_time": s.StartTime,
		"end_time":   s.EndTime,
	})
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "shift not found", http.StatusNotFound)
		return
	}
	
	h.DB.Preload("User").First(&s, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(s)
}

// Delete godoc
// @Summary      Delete shift by ID
// @Tags         shifts
// @Param        id   path      string  true  "Shift ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "shift not found"
// @Router       /shifts/{id} [delete]
func (h Shifts) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	result := h.DB.Delete(&models.Shift{}, "id = ?", id)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "shift not found", http.StatusNotFound)
		return
	}
	
	w.WriteHeader(http.StatusNoContent)
}

// ListByUser godoc
// @Summary      Get all shifts for a user
// @Tags         shifts
// @Produce      json
// @Param        userId   path      string  true  "User ID"
// @Success      200  {array}   models.Shift
// @Router       /shifts/user/{userId} [get]
func (h Shifts) ListByUser(w http.ResponseWriter, r *http.Request) {
	userId, ok := uuidParam(w, r, "userId")
	
	if !ok {
		return
	}
	
	var list []models.Shift
	
	if err := h.DB.Preload("User").Where("user_id = ?", userId).Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// RegisterShifts adds shift routes
func RegisterShifts(router *mux.Router, h Shifts, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/user/{userId}", h.ListByUser).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
