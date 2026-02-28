package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupNotificationsTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.Department{}, &models.Shift{}, &models.Notification{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	SetAuthorizationService(db)
	return db
}

func setupNotificationsRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := Notifications{DB: db}
	RegisterNotifications(router, h, "/notifications")
	return router
}

func TestNotifications_List(t *testing.T) {
	db := setupNotificationsTestDB(t)
	router := setupNotificationsRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("with user returns 200 and list", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Ledelse"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.Notification
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})
}

func TestNotifications_UnreadCount(t *testing.T) {
	db := setupNotificationsTestDB(t)
	router := setupNotificationsRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/notifications/unread-count", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("with user returns 200 and count", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Ledelse"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/notifications/unread-count", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var body map[string]int64
		if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if body["unread_count"] != 0 {
			t.Errorf("unread_count = %d, want 0", body["unread_count"])
		}
	})
}

func TestNotifications_ShiftNotificationsScopedToAssignedUser(t *testing.T) {
	db := setupNotificationsTestDB(t)
	router := setupNotificationsRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "Udvikling"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	owner := models.User{Id: uuid.New(), Name: "Owner", Email: "owner@test.com", PasswordHash: "x", DepartmentId: dept.Id, IsApproved: true}
	owner.Department = dept
	if err := db.Create(&owner).Error; err != nil {
		t.Fatalf("create owner user: %v", err)
	}

	other := models.User{Id: uuid.New(), Name: "Other", Email: "other@test.com", PasswordHash: "x", DepartmentId: dept.Id, IsApproved: true}
	other.Department = dept
	if err := db.Create(&other).Error; err != nil {
		t.Fatalf("create other user: %v", err)
	}

	shift := models.Shift{
		Id:        uuid.New(),
		UserId:    owner.Id,
		StartTime: time.Now().Add(2 * time.Hour),
		EndTime:   time.Now().Add(6 * time.Hour),
	}
	if err := db.Create(&shift).Error; err != nil {
		t.Fatalf("create shift: %v", err)
	}

	relatedType := "shift"
	wrongOwnerNotification := models.Notification{
		Id:                uuid.New(),
		UserId:            owner.Id,
		Title:             "Wrong shift",
		Message:           "Not your shift",
		Type:              models.NotificationTypeShiftCreated,
		CreatedAt:         time.Now(),
		RelatedEntityId:   &shift.Id,
		RelatedEntityType: &relatedType,
	}
	if err := db.Create(&wrongOwnerNotification).Error; err != nil {
		t.Fatalf("create wrong-owner shift notification: %v", err)
	}

	if err := db.Model(&shift).Update("user_id", other.Id).Error; err != nil {
		t.Fatalf("reassign shift: %v", err)
	}

	systemNotification := models.Notification{
		Id:        uuid.New(),
		UserId:    owner.Id,
		Title:     "System",
		Message:   "Visible to owner",
		Type:      models.NotificationTypeSystemAnnouncement,
		CreatedAt: time.Now(),
	}
	if err := db.Create(&systemNotification).Error; err != nil {
		t.Fatalf("create system notification: %v", err)
	}

	// Owner should no longer see/count the shift notification after reassignment.
	req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
	req = requestWithCurrentUser(req, &owner)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", rec.Code, http.StatusOK)
	}

	var list []models.Notification
	if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
		t.Fatalf("decode list: %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("len(list) = %d, want 1", len(list))
	}
	if list[0].Type != models.NotificationTypeSystemAnnouncement {
		t.Fatalf("first notification type = %s, want %s", list[0].Type, models.NotificationTypeSystemAnnouncement)
	}

	countReq := httptest.NewRequest(http.MethodGet, "/notifications/unread-count", nil)
	countReq = requestWithCurrentUser(countReq, &owner)
	countRec := httptest.NewRecorder()
	router.ServeHTTP(countRec, countReq)

	if countRec.Code != http.StatusOK {
		t.Fatalf("count status = %d, want %d", countRec.Code, http.StatusOK)
	}

	var body map[string]int64
	if err := json.NewDecoder(countRec.Body).Decode(&body); err != nil {
		t.Fatalf("decode count: %v", err)
	}
	if body["unread_count"] != 1 {
		t.Fatalf("unread_count = %d, want 1", body["unread_count"])
	}

	// Other user has no notification rows and therefore sees nothing.
	reqOther := httptest.NewRequest(http.MethodGet, "/notifications", nil)
	reqOther = requestWithCurrentUser(reqOther, &other)
	recOther := httptest.NewRecorder()
	router.ServeHTTP(recOther, reqOther)

	if recOther.Code != http.StatusOK {
		t.Fatalf("other list status = %d, want %d", recOther.Code, http.StatusOK)
	}

	var otherList []models.Notification
	if err := json.NewDecoder(recOther.Body).Decode(&otherList); err != nil {
		t.Fatalf("decode other list: %v", err)
	}
	if len(otherList) != 0 {
		t.Fatalf("len(otherList) = %d, want 0", len(otherList))
	}
}

func TestNotifications_MarkRead(t *testing.T) {
	db := setupNotificationsTestDB(t)
	router := setupNotificationsRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "Ledelse"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
	user.Department = dept
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPut, "/notifications/"+uuid.New().String()+"/read", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("marks notification read and returns 204", func(t *testing.T) {
		n := models.Notification{
			Id:        uuid.New(),
			UserId:    user.Id,
			Title:     "Test",
			Message:   "Msg",
			Type:      models.NotificationTypeSystemAnnouncement,
			CreatedAt: time.Now(),
		}
		if err := db.Create(&n).Error; err != nil {
			t.Fatalf("create notification: %v", err)
		}

		req := httptest.NewRequest(http.MethodPut, "/notifications/"+n.Id.String()+"/read", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNoContent {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNoContent)
		}
	})
}
