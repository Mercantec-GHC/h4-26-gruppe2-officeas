package handlers

import (
	"encoding/json"
	"net/http"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// Users holds DB for user handlers
type Users struct {
	DB *gorm.DB
}

// List godoc
// @Summary      Get all users
// @Tags         users
// @Produce      json
// @Success      200  {array}   models.User
// @Router       /users [get]
func (h Users) List(w http.ResponseWriter, r *http.Request) {
	var list []models.User

	if err := h.DB.Preload("Department").Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// GetByID godoc
// @Summary      Get user by ID
// @Tags         users
// @Produce      json
// @Param        id   path      string  true  "User ID"
// @Success      200  {object}  models.User
// @Failure      404  {string}  string  "user not found"
// @Router       /users/{id} [get]
func (h Users) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var u models.User
	
	if err := h.DB.Preload("Department").First(&u, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "user not found", http.StatusNotFound)
			return
		}
	
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

// Create godoc
// @Summary      Create a new user
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        user  body      models.User  true  "User"
// @Success      201  {object}  models.User
// @Failure      400  {string}  string  "Bad request"
// @Router       /users [post]
func (h Users) Create(w http.ResponseWriter, r *http.Request) {
	// Expect plaintext password in request; hash it before storing
	var req struct {
		Name         string    `json:"name"`
		Email        string    `json:"email"`
		Password     string    `json:"password"`
		DepartmentId uuid.UUID `json:"department_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "failed to hash password", http.StatusInternalServerError)
		return
	}

	u := models.User{
		Id:           uuid.New(),
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: string(hashed),
		DepartmentId: req.DepartmentId,
	}

	if err := h.DB.Create(&u).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(u)
}

// Update godoc
// @Summary      Update user by ID
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        id   path      string  true  "User ID"
// @Param        user  body      models.User  true  "User"
// @Success      200  {object}  models.User
// @Failure      404  {string}  string  "user not found"
// @Router       /users/{id} [put]
func (h Users) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	var u models.User
	
	if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	
	u.Id = id
	
	result := h.DB.Model(&models.User{}).Where("id = ?", id).Updates(map[string]interface{}{
		"name":            u.Name,
		"email":           u.Email,
		"password_hash":   u.PasswordHash,
		"department_id":   u.DepartmentId,
		"feedback_rating": u.FeedbackRating,
	})
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}
	
	h.DB.First(&u, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

// Delete godoc
// @Summary      Delete user by ID
// @Tags         users
// @Param        id   path      string  true  "User ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "user not found"
// @Router       /users/{id} [delete]
func (h Users) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	
	if !ok {
		return
	}
	
	result := h.DB.Delete(&models.User{}, "id = ?", id)
	
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	
	if result.RowsAffected == 0 {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}
	
	w.WriteHeader(http.StatusNoContent)
}

// RegisterUsers adds user routes
func RegisterUsers(router *mux.Router, h Users, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
