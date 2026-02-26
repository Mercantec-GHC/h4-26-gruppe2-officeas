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

func setupShiftsTestDB(t *testing.T) *gorm.DB {
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

func setupShiftsRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := Shifts{DB: db}
	RegisterShifts(router, h, "/shifts")
	return router
}

func TestShifts_List(t *testing.T) {
	db := setupShiftsTestDB(t)
	router := setupShiftsRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/shifts", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("with user returns 200 and list", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/shifts", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.Shift
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})
}

func TestShifts_GetByID(t *testing.T) {
	db := setupShiftsTestDB(t)
	router := setupShiftsRouter(t, db)

	t.Run("invalid UUID returns 400", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/shifts/not-a-uuid", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("existing shift returns 200", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u@t.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}
		start := time.Now()
		end := start.Add(8 * time.Hour)
		shift := models.Shift{Id: uuid.New(), UserId: user.Id, StartTime: start, EndTime: end}
		if err := db.Create(&shift).Error; err != nil {
			t.Fatalf("create shift: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/shifts/"+shift.Id.String(), nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.Shift
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Id != shift.Id {
			t.Errorf("got %+v", got)
		}
	})
}

func TestShifts_Create(t *testing.T) {
	db := setupShiftsTestDB(t)
	router := setupShiftsRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "Ledelse"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	user := models.User{Id: uuid.New(), Name: "Manager", Email: "m@t.com", PasswordHash: "x", DepartmentId: dept.Id}
	user.Department = dept
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	targetUser := models.User{Id: uuid.New(), Name: "Target", Email: "target@t.com", PasswordHash: "x", DepartmentId: dept.Id}
	if err := db.Create(&targetUser).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		body := []byte(`{"user_id":"` + targetUser.Id.String() + `","start_time":"2025-01-01T09:00:00Z","end_time":"2025-01-01T17:00:00Z"}`)
		req := httptest.NewRequest(http.MethodPost, "/shifts", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("manager creates shift and returns 201", func(t *testing.T) {
		body := []byte(`{"user_id":"` + targetUser.Id.String() + `","start_time":"2025-01-01T09:00:00Z","end_time":"2025-01-01T17:00:00Z"}`)
		req := httptest.NewRequest(http.MethodPost, "/shifts", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}

		var got models.Shift
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.UserId != targetUser.Id {
			t.Errorf("got user_id %s", got.UserId)
		}
	})
}
