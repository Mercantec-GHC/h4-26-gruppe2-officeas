package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"time"

	"stuff/internal/upload"
	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// Users holds DB and upload dir for user handlers
type Users struct {
	DB        *gorm.DB
	UploadDir string
}

// setUserAvatarURL sets AvatarURL on u for API responses when the user has a profile image.
func setUserAvatarURL(u *models.User) {
	if u != nil && u.ProfileImagePath != "" {
		u.AvatarURL = "/users/" + u.Id.String() + "/avatar"
	}
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
	for i := range list {
		setUserAvatarURL(&list[i])
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
	setUserAvatarURL(&u)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

// UserFeedbackRatingResponse is the JSON response for GET /users/{id}/feedback-rating
type UserFeedbackRatingResponse struct {
	AverageRating float64 `json:"average_rating"`
	FeedbackCount int     `json:"feedback_count"`
}

// ComputeUserFeedbackRatingGORM returns the average feedback rating and count for a user in a department.
// Uses GORM only (Find, Preload, loop); no raw SQL. Shared by GetFeedbackRating and feedback.Create.
func ComputeUserFeedbackRatingGORM(db *gorm.DB, userID, departmentID uuid.UUID) (avg float64, count int) {
	var userShifts []models.Shift
	
	if err := db.Where("user_id = ?", userID).Find(&userShifts).Error; err != nil {
		return 0, 0
	}

	var feedbacks []models.Feedback
	
	if err := db.Where("department_id = ? AND shift_id IS NOT NULL", departmentID).
		Preload("Shift").
		Find(&feedbacks).Error; err != nil {
		return 0, 0
	}
	
	var sum int
	
	for i := range feedbacks {
		f := &feedbacks[i]
	
		if f.Shift == nil {
			continue
		}
	
		for _, us := range userShifts {
			if shiftsOverlap(f.Shift.StartTime, f.Shift.EndTime, us.StartTime, us.EndTime) {
				sum += f.Rating
				count++
				break
			}
		}
	}
	
	if count > 0 {
		avg = float64(sum) / float64(count)
	}
	
	return avg, count
}

// GetFeedbackRating godoc
// @Summary      Get a user's average feedback rating
// @Description  Computes the average rating from all feedback that applies to shifts this user was on (same department). No raw SQL; uses GORM only.
// @Tags         users
// @Produce      json
// @Param        id   path      string  true  "User ID"
// @Success      200  {object}  handlers.UserFeedbackRatingResponse
// @Failure      404  {string}  string  "user not found"
// @Security     BearerAuth
// @Router       /users/{id}/feedback-rating [get]
func (h Users) GetFeedbackRating(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")
	if !ok {
		return
	}

	var user models.User
	if err := h.DB.First(&user, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "user not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	avg, count := ComputeUserFeedbackRatingGORM(h.DB, user.Id, user.DepartmentId)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(UserFeedbackRatingResponse{
		AverageRating: avg,
		FeedbackCount: count,
	})
}

// shiftsOverlap returns true if the two time ranges overlap.
func shiftsOverlap(startA, endA, startB, endB time.Time) bool {
	return startA.Before(endB) && startB.Before(endA)
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
	
	for i := range list {
		setUserAvatarURL(&list[i])
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

	h.DB.WithContext(r.Context()).Preload("Department").First(&u, "id = ?", id)
	setUserAvatarURL(&u)
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
	setUserAvatarURL(&user)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

// UploadProfileImage godoc
// @Summary      Upload profile image (current user)
// @Tags         users
// @Accept       multipart/form-data
// @Produce      json
// @Param        image  formData  file  true  "Profile image"
// @Success      200  {object}  models.User
// @Failure      400  {string}  string  "Bad request"
// @Security     BearerAuth
// @Router       /users/me/profile-image [put]
func (h Users) UploadProfileImage(w http.ResponseWriter, r *http.Request) {
	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	
	if h.UploadDir == "" {
		http.Error(w, "upload not configured", http.StatusInternalServerError)
	
		return
	}
	
	file, _, ext, err := upload.ParseImage(r, upload.FormFieldImage)
	
	if err != nil {
		if errors.Is(err, upload.ErrTooLarge) || errors.Is(err, upload.ErrInvalidType) {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
	
		http.Error(w, err.Error(), http.StatusBadRequest)
	
		return
	}
	
	defer file.Close()

	relPath := "profiles/" + currentUser.Id.String() + ext
	
	if currentUser.ProfileImagePath != "" {
		_ = upload.DeleteFile(h.UploadDir, currentUser.ProfileImagePath)
	}
	
	if err := upload.SaveFile(h.UploadDir, relPath, file); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	if err := h.DB.Model(&models.User{}).Where("id = ?", currentUser.Id).Update("profile_image_path", relPath).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	var u models.User
	
	if err := h.DB.Preload("Department").First(&u, "id = ?", currentUser.Id).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	
	setUserAvatarURL(&u)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

// ServeProfileImage godoc
// @Summary      Serve profile image
// @Tags         users
// @Produce      image/*
// @Param        id   path      string  true  "User ID or 'me'"
// @Success      200  "Image bytes"
// @Failure      404  {string}  string  "not found"
// @Security     BearerAuth
// @Router       /users/{id}/avatar [get]
func (h Users) ServeProfileImage(w http.ResponseWriter, r *http.Request) {
	if h.UploadDir == "" {
		http.Error(w, "upload not configured", http.StatusInternalServerError)
		return
	}

	idStr := mux.Vars(r)["id"]
	
	var userID uuid.UUID
	
	if idStr == "me" {
		_, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	
		if err != nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		userID = currentUser.Id
	} else {
		id, err := uuid.Parse(idStr)

		if err != nil {
			http.Error(w, "invalid user id", http.StatusBadRequest)
			return
		}

		userID = id
	}

	var u models.User

	if err := h.DB.First(&u, "id = ?", userID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "user not found", http.StatusNotFound)

			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)

		return
	}

	if u.ProfileImagePath == "" {
		http.Error(w, "no profile image", http.StatusNotFound)

		return
	}

	if err := upload.ServeFile(w, h.UploadDir, u.ProfileImagePath); err != nil {
		if errors.Is(err, upload.ErrPathEscape) || errors.Is(err, os.ErrNotExist) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)

		return
	}
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
	router.HandleFunc(prefix+"/me/profile-image", h.UploadProfileImage).Methods("PUT")
	router.HandleFunc(prefix+"/me/avatar", h.ServeProfileImage).Methods("GET")
	router.HandleFunc(prefix+"/{id}/avatar", h.ServeProfileImage).Methods("GET")
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.HandleFunc(prefix+"/pending", h.ListPending).Methods("GET")
	router.HandleFunc(prefix, h.Create).Methods("POST")
	router.HandleFunc(prefix+"/{id}/feedback-rating", h.GetFeedbackRating).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}/approve", h.ApproveAccount).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
