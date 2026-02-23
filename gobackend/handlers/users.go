package handlers

import (
	"encoding/json"
	"net/http"
	"time"

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
// @Security     BearerAuth
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
// @Security     BearerAuth
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

// ListPending godoc
// @Summary      Get pending user approvals
// @Tags         users
// @Produce      json
// @Success      200  {array}   models.User
// @Security     BearerAuth
// @Router       /users/pending [get]
func (h Users) ListPending(w http.ResponseWriter, r *http.Request) {
	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if !isLedelse(currentUser) && !isHR(currentUser) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	var list []models.User
	if err := h.DB.WithContext(r.Context()).
		Preload("Department").
		Where("is_approved = ?", false).
		Order("created_at ASC").
		Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// Create godoc
// @Summary      Create a new user
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        user  body      models.User  true  "User"
// @Success      201  {object}  models.User
// @Failure      400  {string}  string  "Bad request"
// @Security     BearerAuth
// @Router       /users [post]
func (h Users) Create(w http.ResponseWriter, r *http.Request) {
	_, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if !isLedelse(currentUser) && !isHR(currentUser) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

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
		Id:               uuid.New(),
		Name:             req.Name,
		Email:            req.Email,
		PasswordHash:     string(hashed),
		DepartmentId:     req.DepartmentId,
		IsApproved:       true,
		ApprovedAt:       func() *time.Time { now := time.Now(); return &now }(),
		ApprovedByUserId: &currentUser.Id,
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
// @Security     BearerAuth
// @Router       /users/{id} [put]
func (h Users) Update(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var existing models.User
	if err := h.DB.WithContext(r.Context()).First(&existing, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "user not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var u models.User

	if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	u.Id = id
	isManager := isLedelse(currentUser) || isHR(currentUser)

	if !isManager {
		if currentUser.Id != id {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		if u.Name != "" && u.Name != existing.Name {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		if u.DepartmentId != uuid.Nil && u.DepartmentId != existing.DepartmentId {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
	}

	updates := map[string]interface{}{
		"name":            u.Name,
		"email":           u.Email,
		"password_hash":   u.PasswordHash,
		"department_id":   existing.DepartmentId,
		"feedback_rating": existing.FeedbackRating,
	}

	if isManager {
		if u.DepartmentId != uuid.Nil {
			updates["department_id"] = u.DepartmentId
		}
		updates["feedback_rating"] = u.FeedbackRating
	} else {
		updates["name"] = existing.Name
	}

	result := h.DB.WithContext(r.Context()).Model(&models.User{}).Where("id = ?", id).Updates(updates)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}

	h.DB.WithContext(r.Context()).First(&u, "id = ?", id)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

// ApproveAccount approves a pending user account. HR/Ledelse only.
func (h Users) ApproveAccount(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if !isLedelse(currentUser) && !isHR(currentUser) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	if currentUser.Id == id {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	var body struct {
		DepartmentId *uuid.UUID `json:"department_id"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)

	now := time.Now()
	updates := map[string]interface{}{
		"is_approved":         true,
		"approved_at":         &now,
		"approved_by_user_id": currentUser.Id,
	}
	if body.DepartmentId != nil {
		updates["department_id"] = *body.DepartmentId
	}

	result := h.DB.WithContext(r.Context()).Model(&models.User{}).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}
	if result.RowsAffected == 0 {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}

	var user models.User
	if err := h.DB.WithContext(r.Context()).Preload("Department").First(&user, "id = ?", id).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

// Delete godoc
// @Summary      Delete user by ID
// @Tags         users
// @Param        id   path      string  true  "User ID"
// @Success      204  "No Content"
// @Failure      404  {string}  string  "user not found"
// @Security     BearerAuth
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
	router.HandleFunc(prefix+"/pending", h.ListPending).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}/approve", h.ApproveAccount).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
