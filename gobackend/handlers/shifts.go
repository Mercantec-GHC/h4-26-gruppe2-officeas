package handlers

import (
	"encoding/json"
	"net/http"
	"sort"
	"time"

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
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /shifts [get]
func (h Shifts) List(w http.ResponseWriter, r *http.Request) {
	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var list []models.Shift
	query := h.DB.WithContext(r.Context()).Preload("User")

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
// @Summary      Get shift by ID
// @Tags         shifts
// @Produce      json
// @Param        id   path      string  true  "Shift ID"
// @Success      200  {object}  models.Shift
// @Failure      404  {string}  string  "shift not found"
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /shifts/{id} [get]
func (h Shifts) GetByID(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var s models.Shift

	if err := h.DB.WithContext(r.Context()).Preload("User").First(&s, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "shift not found", http.StatusNotFound)
			return
		}

		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if !isLedelse(currentUser) && !isHR(currentUser) && s.UserId != currentUser.Id {
		http.Error(w, "forbidden", http.StatusForbidden)
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
// @Security     BearerAuth
// @Security     BearerAuth
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

	relatedType := "shift"
	createNotification(
		h.DB,
		s.UserId,
		"Shift created",
		"A new shift has been assigned to you",
		models.NotificationTypeShiftCreated,
		&s.Id,
		&relatedType,
	)

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
// @Security     BearerAuth
// @Security     BearerAuth
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
// @Security     BearerAuth
// @Security     BearerAuth
// @Router       /shifts/{id} [delete]
func (h Shifts) Delete(w http.ResponseWriter, r *http.Request) {
	id, ok := uuidParam(w, r, "id")

	if !ok {
		return
	}

	var existing models.Shift
	if err := h.DB.First(&existing, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "shift not found", http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
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

	relatedType := "shift"
	createNotification(
		h.DB,
		existing.UserId,
		"Shift cancelled",
		"One of your shifts has been cancelled",
		models.NotificationTypeShiftCancelled,
		&id,
		&relatedType,
	)

	w.WriteHeader(http.StatusNoContent)
}

// ListByUser godoc
// @Summary      Get all shifts for a user
// @Tags         shifts
// @Produce      json
// @Param        userId   path      string  true  "User ID"
// @Success      200  {array}   models.Shift
// @Security     BearerAuth
// @Router       /shifts/user/{userId} [get]
func (h Shifts) ListByUser(w http.ResponseWriter, r *http.Request) {
	userId, ok := uuidParam(w, r, "userId")

	if !ok {
		return
	}

	r, currentUser, err := ensureCurrentUserForAuthorization(r, h.DB)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	if !isLedelse(currentUser) && !isHR(currentUser) && userId != currentUser.Id {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	var list []models.Shift

	if err := h.DB.WithContext(r.Context()).Preload("User").Where("user_id = ?", userId).Find(&list).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(list)
}

// GenerateShiftsRequest is the body for POST /shifts/generate
type GenerateShiftsRequest struct {
	StartDate string `json:"start_date"` // YYYY-MM-DD
	EndDate   string `json:"end_date"`   // YYYY-MM-DD
}

// GenerateShiftsResponse is the response for POST /shifts/generate
type GenerateShiftsResponse struct {
	Created  []models.Shift `json:"created"`
	Warnings []string       `json:"warnings,omitempty"`
}

// Generate godoc
// @Summary      Generate shifts for all departments
// @Description  Creates 4-hour shifts (08:00-12:00 and 12:00-16:00) with 2 people per department per slot. Respects approved absences and balances hours across users. Avoids same-day double-booking when possible.
// @Tags         shifts
// @Accept       json
// @Produce      json
// @Param        body  body      GenerateShiftsRequest  true  "Date range"
// @Success      201   {object}  GenerateShiftsResponse
// @Failure      400   {string}  string  "Bad request"
// @Security     BearerAuth
// @Router       /shifts/generate [post]
func (h Shifts) Generate(w http.ResponseWriter, r *http.Request) {
	var req GenerateShiftsRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	loc, err := time.LoadLocation("Europe/Copenhagen")

	if err != nil {
		loc = time.UTC
	}

	startDate, err := time.ParseInLocation("2006-01-02", req.StartDate, loc)

	if err != nil {
		http.Error(w, "invalid start_date (use YYYY-MM-DD)", http.StatusBadRequest)
		return
	}

	endDate, err := time.ParseInLocation("2006-01-02", req.EndDate, loc)

	if err != nil {
		http.Error(w, "invalid end_date (use YYYY-MM-DD)", http.StatusBadRequest)
		return
	}

	if endDate.Before(startDate) {
		http.Error(w, "end_date must be >= start_date", http.StatusBadRequest)
		return
	}

	// Load departments the same way as GET /departments, but with users
	var departments []models.Department

	if err := h.DB.Preload("Users").Find(&departments).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Load approved absences overlapping the range
	var absences []models.AbsenceRequest

	if err := h.DB.Where("status = ?", models.RequestStatusApproved).
		Where("end_date >= ?", startDate).
		Where("start_date <= ?", endDate).
		Find(&absences).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Build set of (user_id, date) that are absent
	absentSet := make(map[string]bool)
	for _, a := range absences {
		rangeStart := startDate

		if a.StartDate.After(rangeStart) {
			rangeStart = a.StartDate
		}

		rangeEnd := endDate

		if a.EndDate.Before(rangeEnd) {
			rangeEnd = a.EndDate
		}

		for d := rangeStart; !d.After(rangeEnd); d = d.AddDate(0, 0, 1) {
			key := a.UserId.String() + "|" + d.Format("2006-01-02")
			absentSet[key] = true
		}
	}

	// Initialize assigned-shift count per user (all users from departments)
	assignedShifts := make(map[uuid.UUID]int)

	for i := range departments {
		for _, u := range departments[i].Users {
			assignedShifts[u.Id] = 0
		}
	}

	var toCreate []models.Shift
	var warnings []string

	// Iterate each day in range
	for day := startDate; !day.After(endDate); day = day.AddDate(0, 0, 1) {
		dayStr := day.Format("2006-01-02")

		for _, dept := range departments {
			// Assignable = department users not absent on this day
			var assignable []models.User

			for _, u := range dept.Users {
				if !absentSet[u.Id.String()+"|"+dayStr] {
					assignable = append(assignable, u)
				}
			}

			if len(assignable) == 0 {
				warnings = append(warnings, "no assignable users for department "+dept.Name+" on "+dayStr)
				continue
			}

			// Sort by assigned shifts ascending (fair distribution)
			sort.Slice(assignable, func(i, j int) bool {
				return assignedShifts[assignable[i].Id] < assignedShifts[assignable[j].Id]
			})

			// Morning slot: 08:00-12:00 — pick 2 (or 1)
			morningCount := 2

			if len(assignable) < 2 {
				morningCount = len(assignable)
			}

			morningUsers := assignable[:morningCount]
			startMorning := time.Date(day.Year(), day.Month(), day.Day(), 8, 0, 0, 0, loc)
			endMorning := time.Date(day.Year(), day.Month(), day.Day(), 12, 0, 0, 0, loc)

			for _, u := range morningUsers {
				toCreate = append(toCreate, models.Shift{
					Id:        uuid.New(),
					UserId:    u.Id,
					StartTime: startMorning,
					EndTime:   endMorning,
				})

				assignedShifts[u.Id]++
			}

			// Afternoon slot: 12:00-16:00 — prefer users not in morning; fill with morning if needed
			afternoonPool := make([]models.User, 0, len(assignable))
			morningIDs := make(map[uuid.UUID]bool)

			for _, u := range morningUsers {
				morningIDs[u.Id] = true
			}

			for _, u := range assignable {
				if !morningIDs[u.Id] {
					afternoonPool = append(afternoonPool, u)
				}
			}

			sort.Slice(afternoonPool, func(i, j int) bool {
				return assignedShifts[afternoonPool[i].Id] < assignedShifts[afternoonPool[j].Id]
			})
			// Need 2 for afternoon; take from afternoonPool first, then from morningUsers

			var afternoonUsers []models.User

			for _, u := range afternoonPool {
				if len(afternoonUsers) >= 2 {
					break
				}

				afternoonUsers = append(afternoonUsers, u)
			}

			for _, u := range morningUsers {
				if len(afternoonUsers) >= 2 {
					break
				}

				afternoonUsers = append(afternoonUsers, u)
			}

			startAfternoon := time.Date(day.Year(), day.Month(), day.Day(), 12, 0, 0, 0, loc)
			endAfternoon := time.Date(day.Year(), day.Month(), day.Day(), 16, 0, 0, 0, loc)

			for _, u := range afternoonUsers {
				toCreate = append(toCreate, models.Shift{
					Id:        uuid.New(),
					UserId:    u.Id,
					StartTime: startAfternoon,
					EndTime:   endAfternoon,
				})

				assignedShifts[u.Id]++
			}
		}
	}

	// Create shifts in a transaction
	if err := h.DB.Transaction(func(tx *gorm.DB) error {
		for i := range toCreate {
			if err := tx.Create(&toCreate[i]).Error; err != nil {
				return err
			}
		}

		return nil
	}); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Notifications for each created shift
	relatedType := "shift"

	for i := range toCreate {
		createNotification(
			h.DB,
			toCreate[i].UserId,
			"Shift created",
			"A new shift has been assigned to you",
			models.NotificationTypeShiftCreated,
			&toCreate[i].Id,
			&relatedType,
		)
	}

	// Preload User on created shifts for response
	for i := range toCreate {
		_ = h.DB.Preload("User").First(&toCreate[i], "id = ?", toCreate[i].Id).Error
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(GenerateShiftsResponse{Created: toCreate, Warnings: warnings})
}

// RegisterShifts adds shift routes
func RegisterShifts(router *mux.Router, h Shifts, prefix string) {
	router.HandleFunc(prefix, h.List).Methods("GET")
	router.Handle(prefix, chainWithMiddlewares(h.Create, RequirePermission(ShiftManage))).Methods("POST")
	router.Handle(prefix+"/generate", chainWithMiddlewares(h.Generate, RequirePermission(ShiftManage))).Methods("POST")
	router.HandleFunc(prefix+"/user/{userId}", h.ListByUser).Methods("GET")
	router.HandleFunc(prefix+"/{id}", h.GetByID).Methods("GET")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.Update, RequirePermission(ShiftManage))).Methods("PUT")
	router.Handle(prefix+"/{id}", chainWithMiddlewares(h.Delete, RequirePermission(ShiftManage))).Methods("DELETE")
}
