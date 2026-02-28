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

func setupAbsenceRequestCommentsTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.Department{}, &models.AbsenceRequest{}, &models.AbsenceRequestComment{}, &models.Notification{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	SetAuthorizationService(db)
	return db
}

func setupAbsenceRequestCommentsRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := AbsenceRequestComments{DB: db}
	RegisterAbsenceRequestComments(router, h, "/absence-requests", "/absence-request-comments")
	return router
}

func TestAbsenceRequestComments_ListByAbsenceRequest(t *testing.T) {
	db := setupAbsenceRequestCommentsTestDB(t)
	router := setupAbsenceRequestCommentsRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		arID := uuid.New()
		req := httptest.NewRequest(http.MethodGet, "/absence-requests/"+arID.String()+"/comments", nil)
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
		start := time.Date(2025, 6, 1, 0, 0, 0, 0, time.UTC)
		end := time.Date(2025, 6, 5, 0, 0, 0, 0, time.UTC)
		ar := models.AbsenceRequest{
			Id:        uuid.New(),
			UserId:    user.Id,
			Type:      models.AbsenceTypeVacation,
			StartDate: start,
			EndDate:   end,
			Status:    models.RequestStatusPending,
		}
		if err := db.Create(&ar).Error; err != nil {
			t.Fatalf("create absence request: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/absence-requests/"+ar.Id.String()+"/comments", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.AbsenceRequestComment
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})
}

func TestAbsenceRequestComments_CreateOnAbsenceRequest(t *testing.T) {
	db := setupAbsenceRequestCommentsTestDB(t)
	router := setupAbsenceRequestCommentsRouter(t, db)

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
	ar := models.AbsenceRequest{
		Id:        uuid.New(),
		UserId:    user.Id,
		Type:      models.AbsenceTypeVacation,
		StartDate: start,
		EndDate:   end,
		Status:    models.RequestStatusPending,
	}
	if err := db.Create(&ar).Error; err != nil {
		t.Fatalf("create absence request: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		body := []byte(`{"user_id":"` + user.Id.String() + `","content":"A comment"}`)
		req := httptest.NewRequest(http.MethodPost, "/absence-requests/"+ar.Id.String()+"/comments", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("creates comment and returns 201", func(t *testing.T) {
		body := []byte(`{"user_id":"` + user.Id.String() + `","content":"A comment"}`)
		req := httptest.NewRequest(http.MethodPost, "/absence-requests/"+ar.Id.String()+"/comments", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}

		var got models.AbsenceRequestComment
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Content != "A comment" || got.AbsenceRequestId != ar.Id {
			t.Errorf("got %+v", got)
		}
	})
}
