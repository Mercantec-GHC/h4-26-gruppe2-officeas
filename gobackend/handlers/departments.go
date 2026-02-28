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
// @Security     BearerAuth
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
// @Security     BearerAuth
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

// GetByID godoc
// @Summary      Get department by ID
// @Tags         departments
// @Produce      json
// @Param        id   path      string  true  "Department ID"
// @Success      200  {object}  models.Department
// @Failure      404  {string}  string  "department not found"
// @Security     BearerAuth
// @Router       /departments/{id} [get]
func (h Departments) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	var d models.Department
	if err := h.DB.Preload("Users").First(&d, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "department not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(d)
}

// Update godoc
// @Summary      Update department by ID
// @Tags         departments
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "Department ID"
// @Param        department  body      models.Department  true  "Department"
// @Success      200  {object}  models.Department
// @Failure      404  {string}  string  "department not found"
// @Security     BearerAuth
// @Router       /departments/{id} [put]
func (h Departments) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	var d models.Department
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	d.Id = id
	result := h.DB.Model(&models.Department{}).Where("id = ?", id).Updates(map[string]interface{}{
		"name": d.Name,
	})

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	if result.RowsAffected == 0 {
		http.Error(w, "department not found", http.StatusNotFound)
		return
	}

	h.DB.Preload("Users").First(&d, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(d)
}

// Delete godoc
// @Summary      Delete department by ID
// @Tags         departments
// @Param        id   path      string  true  "Department ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "department not found"
// @Security     BearerAuth
// @Router       /departments/{id} [delete]
func (h Departments) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	result := h.DB.Delete(&models.Department{}, "id = ?", id)
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	if result.RowsAffected == 0 {
		http.Error(w, "department not found", http.StatusNotFound)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ListShifts godoc
// @Summary      Get all shifts for all users in a department
// @Tags         departments
// @Produce      json
// @Param        id   path      string  true  "Department ID"
// @Success      200  {array}   models.Shift
// @Failure      404  {string}  string  "department not found"
// @Security     BearerAuth
// @Router       /departments/{id}/shifts [get]
func (h Departments) ListShifts(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	var dept models.Department

	if err := h.DB.First(&dept, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "department not found", http.StatusNotFound)
			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var list []models.Shift
	
	if err := h.DB.Preload("User").Where("user_id IN (?)",
		h.DB.Model(&models.User{}).Select("id").Where("department_id = ?", id),
	).Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// RegisterDepartments adds department routes to router.
// Register /{id}/shifts before /{id} so "shifts" is not matched as id.
func RegisterDepartments(router *mux.Router, h Departments, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	RegisterDepartmentsProtected(router, h, prefix)
}

// RegisterDepartmentsProtected adds department routes except GET list (use when GET list is public).
func RegisterDepartmentsProtected(router *mux.Router, h Departments, prefix string) {
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/{id}/shifts", h.ListShifts).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
