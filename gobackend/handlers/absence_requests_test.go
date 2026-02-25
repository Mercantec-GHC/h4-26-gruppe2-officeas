package handlers

import (
	"bytes"
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

func setupAbsenceRequestsTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.Department{}, &models.AbsenceRequest{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	SetAuthorizationService(db)
	return db
}

func setupAbsenceRequestsRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := AbsenceRequests{DB: db}
	RegisterAbsenceRequests(router, h, "/absence-requests")
	return router
}

func TestAbsenceRequests_List(t *testing.T) {
	db := setupAbsenceRequestsTestDB(t)
	router := setupAbsenceRequestsRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/absence-requests", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("with user returns 200 and list", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Kundeservice"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/absence-requests", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.AbsenceRequest
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})
}

func TestAbsenceRequests_GetByID(t *testing.T) {
	db := setupAbsenceRequestsTestDB(t)
	router := setupAbsenceRequestsRouter(t, db)

	t.Run("invalid UUID returns 400", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Kundeservice"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u-invalid-ar@t.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}
		req := httptest.NewRequest(http.MethodGet, "/absence-requests/not-a-uuid", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("missing request returns 404", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Kundeservice"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u-missing-ar@t.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/absence-requests/"+uuid.New().String(), nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})
}

func TestAbsenceRequests_Create(t *testing.T) {
	db := setupAbsenceRequestsTestDB(t)
	router := setupAbsenceRequestsRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "Kundeservice"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
	user.Department = dept
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	start := time.Date(2025, 6, 1, 0, 0, 0, 0, time.UTC)
	end := time.Date(2025, 6, 5, 0, 0, 0, 0, time.UTC)

	t.Run("no current user returns 401", func(t *testing.T) {
		body := []byte(`{"type":"VACATION","start_date":"2025-06-01","end_date":"2025-06-05"}`)
		req := httptest.NewRequest(http.MethodPost, "/absence-requests", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("creates absence request and returns 201", func(t *testing.T) {
		body := []byte(`{"type":"VACATION","start_date":"2025-06-01T00:00:00Z","end_date":"2025-06-05T00:00:00Z"}`)
		req := httptest.NewRequest(http.MethodPost, "/absence-requests", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}

		var got models.AbsenceRequest
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.UserId != user.Id || got.Type != models.AbsenceTypeVacation {
			t.Errorf("got %+v", got)
		}
		if got.StartDate != start || got.EndDate != end {
			t.Errorf("dates: start=%v end=%v", got.StartDate, got.EndDate)
		}
	})
}
