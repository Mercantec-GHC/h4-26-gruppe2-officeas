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

func setupDepartmentsTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.Department{}, &models.User{}, &models.Shift{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func setupDepartmentsRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := Departments{DB: db}
	RegisterDepartments(router, h, "/departments")
	return router
}

func TestDepartments_List(t *testing.T) {
	db := setupDepartmentsTestDB(t)
	router := setupDepartmentsRouter(t, db)

	t.Run("empty list returns 200 and empty array", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/departments", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.Department
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})

	t.Run("returns departments", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/departments", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.Department
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 1 || list[0].Name != "IT" {
			t.Errorf("list = %+v", list)
		}
	})
}

func TestDepartments_GetByID(t *testing.T) {
	db := setupDepartmentsTestDB(t)
	router := setupDepartmentsRouter(t, db)

	t.Run("invalid UUID returns 400", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/departments/not-a-uuid", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("missing department returns 404", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/departments/"+uuid.New().String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("existing department returns 200", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "HR"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/departments/"+dept.Id.String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.Department
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Name != "HR" {
			t.Errorf("got %+v", got)
		}
	})
}

func TestDepartments_Create(t *testing.T) {
	db := setupDepartmentsTestDB(t)
	router := setupDepartmentsRouter(t, db)

	t.Run("creates department and returns 201", func(t *testing.T) {
		body := []byte(`{"name":"New Dept"}`)
		req := httptest.NewRequest(http.MethodPost, "/departments", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}

		var got models.Department
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Name != "New Dept" || got.Id == uuid.Nil {
			t.Errorf("got %+v", got)
		}
	})
}

func TestDepartments_Update(t *testing.T) {
	db := setupDepartmentsTestDB(t)
	router := setupDepartmentsRouter(t, db)

	t.Run("missing department returns 404", func(t *testing.T) {
		body := []byte(`{"name":"Updated"}`)
		req := httptest.NewRequest(http.MethodPut, "/departments/"+uuid.New().String(), bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("updates department and returns 200", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Old"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		body := []byte(`{"name":"Updated Name"}`)
		req := httptest.NewRequest(http.MethodPut, "/departments/"+dept.Id.String(), bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.Department
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Name != "Updated Name" {
			t.Errorf("got %+v", got)
		}
	})
}

func TestDepartments_Delete(t *testing.T) {
	db := setupDepartmentsTestDB(t)
	router := setupDepartmentsRouter(t, db)

	t.Run("missing department returns 404", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/departments/"+uuid.New().String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("deletes department and returns 204", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "ToDelete"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		req := httptest.NewRequest(http.MethodDelete, "/departments/"+dept.Id.String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNoContent {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNoContent)
		}

		var count int64
		db.Model(&models.Department{}).Where("id = ?", dept.Id).Count(&count)
		if count != 0 {
			t.Error("department still exists after delete")
		}
	})
}

func TestDepartments_ListShifts(t *testing.T) {
	db := setupDepartmentsTestDB(t)
	router := setupDepartmentsRouter(t, db)

	t.Run("missing department returns 404", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/departments/"+uuid.New().String()+"/shifts", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("returns shifts for department users", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		user := models.User{
			Id:           uuid.New(),
			Name:         "User",
			Email:        "u@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		start := time.Now()
		end := start.Add(8 * time.Hour)
		shift := models.Shift{Id: uuid.New(), UserId: user.Id, StartTime: start, EndTime: end}
		if err := db.Create(&shift).Error; err != nil {
			t.Fatalf("create shift: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/departments/"+dept.Id.String()+"/shifts", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.Shift
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 1 {
			t.Errorf("len(list) = %d, want 1", len(list))
		}
	})
}
