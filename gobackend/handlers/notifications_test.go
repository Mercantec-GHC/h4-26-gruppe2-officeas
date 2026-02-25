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
	if err := db.AutoMigrate(&models.User{}, &models.Department{}, &models.Notification{}); err != nil {
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
