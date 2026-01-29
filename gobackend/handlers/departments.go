package handlers

import (
	"encoding/json"
	"net/http"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/gorm"
)

// Departments holds DB for department handlers
type Departments struct {
	DB *gorm.DB
}

// List godoc
// @Summary      Get all departments
// @Tags         departments
// @Produce      json
// @Success      200  {array}   models.Department
// @Router       /departments [get]
func (h Departments) List(w http.ResponseWriter, r *http.Request) {
	var list []models.Department

	if err := h.DB.Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// Create godoc
// @Summary      Create a new department
// @Tags         departments
// @Accept       json
// @Produce      json
// @Param        department  body      models.Department  true  "Department"
// @Success      201  {object}  models.Department
// @Router       /departments [post]
func (h Departments) Create(w http.ResponseWriter, r *http.Request) {
	var d models.Department
	
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	d.Id = uuid.New()
	
	if err := h.DB.Create(&d).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(d)
}

// RegisterDepartments adds department routes to router (no :id routes)
func RegisterDepartments(router *mux.Router, h Departments, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
}
