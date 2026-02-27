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
// @Description  Returns all feedback entries
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
// @Summary      Create feedback
// @Description  Create feedback for the logged-in user's department
// @Tags         feedback
// @Accept       json
// @Produce      json
// @Param        feedback  body      handlers.FeedbackCreateRequest  true  "Feedback"
// @Success      201  {object}  models.Feedback
// @Failure      401  {string}  string  "Unauthorized"
// @Security     BearerAuth
// @Router       /feedback [post]
func (h Feedback) Create(w http.ResponseWriter, r *http.Request) {

	// 1️⃣ Hent userID fra JWT
	userIDStr, ok := GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		http.Error(w, "invalid user id", http.StatusBadRequest)
		return
	}

	// Find bruger
	var user models.User
	if err := h.DB.First(&user, "id = ?", userID).Error; err != nil {
		http.Error(w, "user not found", http.StatusUnauthorized)
		return
	}


	if user.DepartmentId == uuid.Nil {
		http.Error(w, "user has no department", http.StatusBadRequest)
		return
	}

	//  Decode body (DTO)
	var req FeedbackCreateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if req.Rating < 1 || req.Rating > 10 {
		http.Error(w, "rating must be between 1 and 10", http.StatusBadRequest)
		return
	}

	departmentID := user.DepartmentId
	if req.DepartmentId != nil && *req.DepartmentId != "" {
		parsed, err := uuid.Parse(*req.DepartmentId)
		if err != nil {
			http.Error(w, "invalid department_id", http.StatusBadRequest)
			return
		}
		var dept models.Department
		if err := h.DB.First(&dept, "id = ?", parsed).Error; err != nil {
			http.Error(w, "department not found", http.StatusBadRequest)
			return
		}
		departmentID = dept.Id
	}

	// Shift is required: feedback is about a specific shift (the time period of the experience)
	if req.ShiftId == nil || *req.ShiftId == "" {
		http.Error(w, "shift_id is required", http.StatusBadRequest)
		return
	}
	shiftID, err := uuid.Parse(*req.ShiftId)
	if err != nil {
		http.Error(w, "invalid shift_id", http.StatusBadRequest)
		return
	}
	var refShift models.Shift
	if err := h.DB.First(&refShift, "id = ?", shiftID).Error; err != nil {
		http.Error(w, "shift not found", http.StatusBadRequest)
		return
	}

	// Find all users in the department who had a shift overlapping this time (GORM)
	var overlappingUserIDs []uuid.UUID
	err = h.DB.Model(&models.Shift{}).
		Joins("JOIN users ON users.id = shifts.user_id AND users.department_id = ?", departmentID).
		Where("shifts.start_time < ? AND ? < shifts.end_time", refShift.EndTime, refShift.StartTime).
		Distinct("shifts.user_id").
		Pluck("shifts.user_id", &overlappingUserIDs).Error
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if len(overlappingUserIDs) == 0 {
		http.Error(w, "no one from that department was on shift at that time", http.StatusBadRequest)
		return
	}

	f := models.Feedback{
		Id:           uuid.New(),
		DepartmentId: departmentID,
		ShiftId:      &shiftID,
		Rating:       req.Rating,
		Message:      req.Message,
	}
	if err := h.DB.Create(&f).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Recompute feedback_rating for each affected user using same GORM-only logic as GET /users/{id}/feedback-rating
	for _, uid := range overlappingUserIDs {
		avg, _ := ComputeUserFeedbackRatingGORM(h.DB, uid, departmentID)
		rating := 0
		
		if avg > 0 {
			// Round to nearest int: int() truncates, so adding 0.5 before converting gives proper rounding (e.g. 7.6 → 8).
			rating = int(avg + 0.5)
		}

		h.DB.Model(&models.User{}).Where("id = ?", uid).Update("feedback_rating", rating)
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
// @Param        id        path      string            true  "Feedback ID"
// @Param        feedback  body      models.Feedback   true  "Feedback"
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

	// GET /api/feedback
	router.HandleFunc(prefix, h.List).Methods("GET")

	// POST /api/feedback (KRÆVER LOGIN)
	router.Handle(
		prefix,
		AuthMiddleware(http.HandlerFunc(h.Create)),
	).Methods("POST")

	// CRUD
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.Update).Methods("PUT")
	router.HandleFunc(prefix+"/{id}", h.Delete).Methods("DELETE")
}
