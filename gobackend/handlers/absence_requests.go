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
	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var list []models.AbsenceRequest
	query := h.DB.WithContext(r.Context()).Preload("User").Preload("ReviewedByUser").Preload("Comments")

	if !isLedelse(currentUser) && !isHR(currentUser) {
		query = query.Where("user_id = ?", currentUser.Id)
	}

	if err := query.Find(&list).Error; err != nil {
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

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var a models.AbsenceRequest

	if err := h.DB.WithContext(r.Context()).Preload("User").Preload("ReviewedByUser").Preload("Comments").First(&a, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "absence request not found", http.StatusNotFound)
			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if !CanAccessAbsenceRequest(currentUser, &a) {
		http.Error(w, "forbidden", http.StatusForbidden)
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
	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var a models.AbsenceRequest

	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	a.Id = uuid.New()

	if !isLedelse(currentUser) {
		if a.UserId != uuid.Nil && a.UserId != currentUser.Id {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		a.UserId = currentUser.Id
	}

	if a.Status == "" {
		a.Status = models.RequestStatusPending
	}

	if err := h.DB.WithContext(r.Context()).Create(&a).Error; err != nil {
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

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var existing models.AbsenceRequest
	if err := h.DB.WithContext(r.Context()).First(&existing, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "absence request not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var a models.AbsenceRequest

	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	a.Id = id

	canReview := isLedelse(currentUser) || isHR(currentUser)
	isOwner := existing.UserId == currentUser.Id

	if !canReview && !isOwner {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	if canReview && !isLedelse(currentUser) && existing.UserId == currentUser.Id && (a.Status == models.RequestStatusApproved || a.Status == models.RequestStatusRejected) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	updates := map[string]interface{}{
		"user_id":             existing.UserId,
		"type":                a.Type,
		"start_date":          a.StartDate,
		"end_date":            a.EndDate,
		"shift_id":            a.ShiftId,
		"status":              existing.Status,
		"reviewed_by_user_id": existing.ReviewedByUserId,
	}

	if canReview {
		updates["status"] = a.Status
		updates["reviewed_by_user_id"] = a.ReviewedByUserId
	}

	if canReview && (a.Status == models.RequestStatusApproved || a.Status == models.RequestStatusRejected) {
		now := time.Now()
		updates["reviewed_at"] = &now
	}

	result := h.DB.WithContext(r.Context()).Model(&models.AbsenceRequest{}).Where("id = ?", id).Updates(updates)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "absence request not found", http.StatusNotFound)
		return
	}

	h.DB.WithContext(r.Context()).Preload("User").Preload("ReviewedByUser").Preload("Comments").First(&a, "id = ?", id)

	if existing.Status != a.Status {
		relatedType := "absence_request"
		switch a.Status {
		case models.RequestStatusApproved:
			createNotification(
				h.DB,
				a.UserId,
				"Absence request approved",
				"Your absence request has been approved",
				models.NotificationTypeAbsenceApproved,
				&a.Id,
				&relatedType,
			)
		case models.RequestStatusRejected:
			createNotification(
				h.DB,
				a.UserId,
				"Absence request rejected",
				"Your absence request has been rejected",
				models.NotificationTypeAbsenceRejected,
				&a.Id,
				&relatedType,
			)
		}
	}

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

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var existing models.AbsenceRequest
	if err := h.DB.WithContext(r.Context()).First(&existing, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "absence request not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)

		return
	}

	if !isLedelse(currentUser) && !isHR(currentUser) && existing.UserId != currentUser.Id {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	// Delete comments first (foreign key from absence_request_comments to absence_requests)
	if err := h.DB.WithContext(r.Context()).Where("absence_request_id = ?", id).Delete(&models.AbsenceRequestComment{}).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := h.DB.WithContext(r.Context()).Delete(&models.AbsenceRequest{}, "id = ?", id).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
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

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if !HasPermission(currentUser, AbsenceRequestReview) {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	// Check if request exists
	var a models.AbsenceRequest

	if err := h.DB.WithContext(r.Context()).First(&a, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "absence request not found", http.StatusNotFound)
			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if !isLedelse(currentUser) && a.UserId == currentUser.Id {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	// Parse optional reviewed_by_user_id from body
	var body struct {
		ReviewedByUserId *uuid.UUID `json:"reviewed_by_user_id"`
	}

	// Body is optional, so ignore decode errors
	_ = json.NewDecoder(r.Body).Decode(&body)

	now := time.Now()
	reviewedBy := currentUser.Id
	updates := map[string]interface{}{
		"status":              models.RequestStatusApproved,
		"reviewed_at":         &now,
		"reviewed_by_user_id": reviewedBy,
	}

	if body.ReviewedByUserId != nil {
		if !isLedelse(currentUser) && *body.ReviewedByUserId != currentUser.Id {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		updates["reviewed_by_user_id"] = body.ReviewedByUserId
	}

	result := h.DB.WithContext(r.Context()).Model(&models.AbsenceRequest{}).Where("id = ?", id).Updates(updates)

	if result.Error != nil {
		http.Error(w, result.Error.Error(), http.StatusInternalServerError)
		return
	}

	if result.RowsAffected == 0 {
		http.Error(w, "absence request not found", http.StatusNotFound)
		return
	}

	h.DB.WithContext(r.Context()).Preload("User").Preload("ReviewedByUser").Preload("Comments").First(&a, "id = ?", id)
	if a.UserId != uuid.Nil {
		relatedType := "absence_request"
		createNotification(
			h.DB,
			a.UserId,
			"Absence request approved",
			"Your absence request has been approved",
			models.NotificationTypeAbsenceApproved,
			&a.Id,
			&relatedType,
		)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(a)
}

// ReportSickToday godoc
// @Summary      Report sick for today (same-day sick report)
// @Description  Creates an absence request for today with type SICK_LEAVE and immediately approves it. Deletes any shifts the user has for today. Returns 409 if the user already has an approved absence for today.
// @Tags         absence-requests
// @Produce      json
// @Success      201  {object}  models.AbsenceRequest
// @Failure      409  {string}  string  "already has approved absence for today"
// @Security     BearerAuth
// @Router       /absence-requests/sick-today [post]
func (h AbsenceRequests) ReportSickToday(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserUUID(r)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	today := time.Now().UTC().Truncate(24 * time.Hour)

	var count int64

	if err := h.DB.Model(&models.AbsenceRequest{}).
		Where("user_id = ?", userID).
		Where("status = ?", models.RequestStatusApproved).
		Where("start_date <= ?", today).
		Where("end_date >= ?", today).
		Count(&count).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if count > 0 {
		http.Error(w, "Already has approved absence for today", http.StatusConflict)
		return
	}

	now := time.Now()
	reviewedBy := userID

	a := models.AbsenceRequest{
		Id:               uuid.New(),
		UserId:           userID,
		Type:             models.AbsenceTypeSickLeave,
		StartDate:        today,
		EndDate:          today,
		Status:           models.RequestStatusApproved,
		CreatedAt:        now,
		ReviewedAt:       &now,
		ReviewedByUserId: &reviewedBy,
	}

	if err := h.DB.Create(&a).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	comment := models.AbsenceRequestComment{
		Id:               uuid.New(),
		AbsenceRequestId: a.Id,
		UserId:           userID,
		Content:          "Same-day sick report",
		CreatedAt:        now,
		UpdatedAt:        now,
	}

	if err := h.DB.Create(&comment).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Delete any shifts the user has for today (UTC date)
	tomorrow := today.Add(24 * time.Hour)
	if err := h.DB.Where("user_id = ?", userID).
		Where("start_time >= ?", today).
		Where("start_time < ?", tomorrow).
		Delete(&models.Shift{}).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	relatedType := "absence_request"
	createNotification(
		h.DB,
		userID,
		"Absence approved",
		"Your same-day sick report has been registered.",
		models.NotificationTypeAbsenceApproved,
		&a.Id,
		&relatedType,
	)

	h.DB.Preload("User").Preload("ReviewedByUser").Preload("Comments").First(&a, "id = ?", a.Id)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(a)
}

// RegisterAbsenceRequests adds absence request routes.
func RegisterAbsenceRequests(router *mux.Router, h AbsenceRequests, prefix string) {
	router.Handle(prefix, chainWithMiddlewares(h.List, RequirePermission(AbsenceRequestCreate))).Methods("GET")
	router.Handle(prefix, chainWithMiddlewares(h.Create, RequirePermission(AbsenceRequestCreate))).Methods("POST")
	router.HandleFunc(prefix+"/sick-today", h.ReportSickToday).Methods("POST")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.GetByID, RequirePermission(AbsenceRequestCreate))).Methods("GET")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.Update, RequirePermission(AbsenceRequestCreate))).Methods("PUT")
	router.Handle(prefix+"/{id}/approve", chainWithMiddlewares(h.Approve, RequirePermission(AbsenceRequestReview))).Methods("PUT")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.Delete, RequirePermission(AbsenceRequestCreate))).Methods("DELETE")
}
