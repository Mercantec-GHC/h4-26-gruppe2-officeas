package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupAuthTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.Department{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func setupAuthRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := Auth{DB: db}
	RegisterAuth(router, h, "/auth")
	return router
}

func TestAuth_Login(t *testing.T) {
	if os.Getenv("JWT_SECRET") == "" {
		os.Setenv("JWT_SECRET", "test-secret-for-unit-tests-only")
		defer os.Unsetenv("JWT_SECRET")
	}

	db := setupAuthTestDB(t)
	router := setupAuthRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "IT"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	hashed, _ := bcrypt.GenerateFromPassword([]byte("Password123!"), bcrypt.DefaultCost)
	approvedUser := models.User{
		Id:           uuid.New(),
		Name:         "Approved User",
		Email:        "approved@test.com",
		PasswordHash: string(hashed),
		DepartmentId: dept.Id,
		IsApproved:   true,
	}
	if err := db.Create(&approvedUser).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	pendingUser := models.User{
		Id:           uuid.New(),
		Name:         "Pending User",
		Email:        "pending@test.com",
		PasswordHash: string(hashed),
		DepartmentId: dept.Id,
		IsApproved:   false,
	}
	if err := db.Create(&pendingUser).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	t.Run("invalid JSON returns 400", func(t *testing.T) {
		body := []byte(`{invalid`)
		req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("invalid email format returns 400", func(t *testing.T) {
		body := []byte(`{"email":"not-an-email","password":"x"}`)
		req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("user not found returns 401", func(t *testing.T) {
		body := []byte(`{"email":"nobody@test.com","password":"Password123!"}`)
		req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("wrong password returns 401", func(t *testing.T) {
		body := []byte(`{"email":"approved@test.com","password":"WrongPassword"}`)
		req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("unapproved user returns 403", func(t *testing.T) {
		body := []byte(`{"email":"pending@test.com","password":"Password123!"}`)
		req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusForbidden {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusForbidden)
		}
	})

	t.Run("valid credentials returns 200 and token", func(t *testing.T) {
		body := []byte(`{"email":"approved@test.com","password":"Password123!"}`)
		req := httptest.NewRequest(http.MethodPost, "/auth/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var res LoginResponse
		if err := json.NewDecoder(rec.Body).Decode(&res); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if res.Token == "" {
			t.Error("expected non-empty token")
		}
		if res.User.Email != "approved@test.com" {
			t.Errorf("user email = %q", res.User.Email)
		}
	})
}
