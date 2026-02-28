package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
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

func setupFeedbackTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.Department{}, &models.User{}, &models.Shift{}, &models.Feedback{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

// testUserContextMiddleware sets UserIDKey in context so Create (which uses GetUserIDFromContext) sees a user without requiring a real JWT.
func testUserContextMiddleware(userID string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := context.WithValue(r.Context(), UserIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func setupFeedbackRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := Feedback{DB: db}
	RegisterFeedback(router, h, "/feedback")
	return router
}

func TestFeedback_List(t *testing.T) {
	db := setupFeedbackTestDB(t)
	router := setupFeedbackRouter(t, db)

	t.Run("empty list returns 200 and empty array", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/feedback", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.Feedback
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})
}

func TestFeedback_GetByID(t *testing.T) {
	db := setupFeedbackTestDB(t)
	router := setupFeedbackRouter(t, db)

	t.Run("missing feedback returns 404", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/feedback/"+uuid.New().String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("existing feedback returns 200", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		fb := models.Feedback{Id: uuid.New(), DepartmentId: dept.Id, Rating: 5}
		if err := db.Create(&fb).Error; err != nil {
			t.Fatalf("create feedback: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/feedback/"+fb.Id.String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.Feedback
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Rating != 5 {
			t.Errorf("got %+v", got)
		}
	})
}

func TestFeedback_Create(t *testing.T) {
	db := setupFeedbackTestDB(t)

	dept := models.Department{Id: uuid.New(), Name: "IT"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	user := models.User{
		Id:           uuid.New(),
		Name:         "Test User",
		Email:        "test@example.com",
		PasswordHash: "x",
		DepartmentId: dept.Id,
		IsApproved:   true,
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	// Shift is required by the handler; create one for the test user so overlap query finds someone
	start := time.Date(2025, 2, 25, 8, 0, 0, 0, time.UTC)
	end := time.Date(2025, 2, 25, 12, 0, 0, 0, time.UTC)
	shift := models.Shift{
		Id:        uuid.New(),
		UserId:    user.Id,
		StartTime: start,
		EndTime:   end,
	}
	if err := db.Create(&shift).Error; err != nil {
		t.Fatalf("create shift: %v", err)
	}

	// Router with POST /feedback wrapped in test middleware (simulates auth context) instead of AuthMiddleware
	router := mux.NewRouter()
	h := Feedback{DB: db}
	router.Handle("/feedback", testUserContextMiddleware(user.Id.String())(http.HandlerFunc(h.Create))).Methods("POST")

	t.Run("creates feedback and returns 201", func(t *testing.T) {
		body := []byte(`{"rating":4,"shift_id":"` + shift.Id.String() + `"}`)
		req := httptest.NewRequest(http.MethodPost, "/feedback", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			body, _ := io.ReadAll(rec.Body)
			t.Fatalf("status = %d, want %d; body: %s", rec.Code, http.StatusCreated, string(body))
		}

		var got models.Feedback
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Rating != 4 || got.Id == uuid.Nil {
			t.Errorf("got %+v", got)
		}
	})
}

func TestFeedback_Update(t *testing.T) {
	db := setupFeedbackTestDB(t)
	router := setupFeedbackRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "IT"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	t.Run("updates feedback and returns 200", func(t *testing.T) {
		fb := models.Feedback{Id: uuid.New(), DepartmentId: dept.Id, Rating: 3}
		if err := db.Create(&fb).Error; err != nil {
			t.Fatalf("create feedback: %v", err)
		}

		body := []byte(`{"department_id":"` + dept.Id.String() + `","rating":1}`)
		req := httptest.NewRequest(http.MethodPut, "/feedback/"+fb.Id.String(), bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.Feedback
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Rating != 1 {
			t.Errorf("got %+v", got)
		}
	})
}

func TestFeedback_Delete(t *testing.T) {
	db := setupFeedbackTestDB(t)
	router := setupFeedbackRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "IT"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	t.Run("missing feedback returns 404", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/feedback/"+uuid.New().String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("deletes feedback and returns 204", func(t *testing.T) {
		fb := models.Feedback{Id: uuid.New(), DepartmentId: dept.Id, Rating: 2}
		if err := db.Create(&fb).Error; err != nil {
			t.Fatalf("create feedback: %v", err)
		}

		req := httptest.NewRequest(http.MethodDelete, "/feedback/"+fb.Id.String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNoContent {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNoContent)
		}

		var count int64
		db.Model(&models.Feedback{}).Where("id = ?", fb.Id).Count(&count)
		if count != 0 {
			t.Error("feedback still exists after delete")
		}
	})
}
