package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupTestDB(t *testing.T) *gorm.DB {
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

func setupRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := Users{DB: db}
	RegisterUsers(router, h, "/users")
	return router
}

// requestWithCurrentUser sets the current user in the request context so ensureCurrentUserForAuthorization
// and GetUserIDFromContext (e.g. for notifications) succeed.
func requestWithCurrentUser(r *http.Request, user *models.User) *http.Request {
	ctx := context.WithValue(r.Context(), currentUserContextKey, user)
	ctx = context.WithValue(ctx, UserIDKey, user.Id.String())
	return r.WithContext(ctx)
}

func TestUsers_List(t *testing.T) {
	db := setupTestDB(t)
	router := setupRouter(t, db)

	t.Run("empty list returns 200 and empty array", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/users", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.User
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode body: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})

	t.Run("returns users with department preloaded", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Test department"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		user := models.User{
			Id: 	uuid.New(),
			Name: "Test user",
			Email: "test@test.test",
			PasswordHash: "Password123",
			DepartmentId: dept.Id,
		}

		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/users", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.User

		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode body: %v", err)
		}
		if len(list) != 1 {
			t.Errorf("len(list) = %d, want 1", len(list))
		}
		if list[0].Id != user.Id || list[0].Email != "test@test.test" {
			t.Errorf("user = %+v", list[0])
		}

		if list[0].Department.Name != "Test department" {
			t.Errorf("department not preloaded: %+v", list[0].Department)
		}
	})
}

func TestUsers_GetByID(t *testing.T) {
	db := setupTestDB(t)
	router := setupRouter(t, db)

	t.Run("invalid UUID returns 400", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/users/not-a-uuid", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("missing user returns 404", func(t *testing.T) {
		id := uuid.New()
		req := httptest.NewRequest(http.MethodGet, "/users/"+id.String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("existing user returns 200 and user", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		user := models.User{
			Id:           uuid.New(),
			Name:         "Alice",
			Email:        "alice@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/users/"+user.Id.String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.User
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Id != user.Id || got.Email != "alice@test.com" {
			t.Errorf("got %+v", got)
		}
	})
}

func TestUsers_Delete(t *testing.T) {
	db := setupTestDB(t)
	router := setupRouter(t, db)

	t.Run("missing user returns 404", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodDelete, "/users/"+uuid.New().String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
		}
	})

	t.Run("existing user returns 204 and is deleted", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		user := models.User{
			Id:           uuid.New(),
			Name:         "ToDelete",
			Email:        "delete@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodDelete, "/users/"+user.Id.String(), nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusNoContent {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusNoContent)
		}

		var count int64
		db.Model(&models.User{}).Where("id = ?", user.Id).Count(&count)
		if count != 0 {
			t.Errorf("user still exists after delete")
		}
	})
}

func TestUsers_ListPending(t *testing.T) {
	db := setupTestDB(t)
	router := setupRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/users/pending", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("non-manager returns 403", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		user := models.User{
			Id:           uuid.New(),
			Name:         "Bob",
			Email:        "bob@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/users/pending", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusForbidden {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusForbidden)
		}
	})

	t.Run("manager returns 200 and list", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "Ledelse"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		user := models.User{
			Id:           uuid.New(),
			Name:         "Manager",
			Email:        "manager@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/users/pending", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.User
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		// May be empty or contain pending users from other subtests
		_ = list
	})
}

func TestUsers_Create(t *testing.T) {
	db := setupTestDB(t)
	router := setupRouter(t, db)
	dept := models.Department{Id: uuid.New(), Name: "IT"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		body := []byte(`{"name":"New","email":"new@test.com","password":"Secret1!","department_id":"` + dept.Id.String() + `"}`)
		req := httptest.NewRequest(http.MethodPost, "/users", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("non-manager returns 403", func(t *testing.T) {
		user := models.User{
			Id:           uuid.New(),
			Name:         "Bob",
			Email:        "bob2@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		body := []byte(`{"name":"New","email":"new2@test.com","password":"Secret1!","department_id":"` + dept.Id.String() + `"}`)
		req := httptest.NewRequest(http.MethodPost, "/users", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusForbidden {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusForbidden)
		}
	})

	t.Run("manager creates user and returns 201", func(t *testing.T) {
		ledelseDept := models.Department{Id: uuid.New(), Name: "Ledelse"}
		if err := db.Create(&ledelseDept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		manager := models.User{
			Id:           uuid.New(),
			Name:         "Manager",
			Email:        "manager2@test.com",
			PasswordHash: "x",
			DepartmentId: ledelseDept.Id,
		}
		manager.Department = ledelseDept
		if err := db.Create(&manager).Error; err != nil {
			t.Fatalf("create manager: %v", err)
		}

		body := []byte(`{"name":"Created User","email":"created@test.com","password":"Secret1!","department_id":"` + dept.Id.String() + `"}`)
		req := httptest.NewRequest(http.MethodPost, "/users", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &manager)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}

		var got models.User
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Name != "Created User" || got.Email != "created@test.com" {
			t.Errorf("got %+v", got)
		}
		if got.Id == uuid.Nil {
			t.Error("expected non-nil id")
		}
	})
}

func TestUsers_Update(t *testing.T) {
	db := setupTestDB(t)
	router := setupRouter(t, db)
	dept := models.Department{Id: uuid.New(), Name: "IT"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		userID := uuid.New()
		body := []byte(`{"name":"X","email":"x@test.com","password_hash":"","department_id":"00000000-0000-0000-0000-000000000000","feedback_rating":0}`)
		req := httptest.NewRequest(http.MethodPut, "/users/"+userID.String(), bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("manager can update another user", func(t *testing.T) {
		ledelseDept := models.Department{Id: uuid.New(), Name: "Ledelse"}
		if err := db.Create(&ledelseDept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		manager := models.User{
			Id:           uuid.New(),
			Name:         "Manager",
			Email:        "mgr@test.com",
			PasswordHash: "x",
			DepartmentId: ledelseDept.Id,
		}
		manager.Department = ledelseDept
		if err := db.Create(&manager).Error; err != nil {
			t.Fatalf("create manager: %v", err)
		}

		other := models.User{
			Id:           uuid.New(),
			Name:         "Other",
			Email:        "other@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		if err := db.Create(&other).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		body := []byte(`{"name":"Updated Name","email":"other@test.com","password_hash":"","department_id":"` + dept.Id.String() + `","feedback_rating":5}`)
		req := httptest.NewRequest(http.MethodPut, "/users/"+other.Id.String(), bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &manager)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.User
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Name != "Updated Name" || got.FeedbackRating != 5 {
			t.Errorf("got %+v", got)
		}
	})

	t.Run("non-manager cannot update another user", func(t *testing.T) {
		regular := models.User{
			Id:           uuid.New(),
			Name:         "Regular",
			Email:        "reg@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		regular.Department = dept
		if err := db.Create(&regular).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		other := models.User{
			Id:           uuid.New(),
			Name:         "Other2",
			Email:        "other2@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
		}
		if err := db.Create(&other).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		body := []byte(`{"name":"Hacked","email":"other2@test.com","password_hash":"","department_id":"` + dept.Id.String() + `","feedback_rating":0}`)
		req := httptest.NewRequest(http.MethodPut, "/users/"+other.Id.String(), bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &regular)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusForbidden {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusForbidden)
		}
	})
}

func TestUsers_ApproveAccount(t *testing.T) {
	db := setupTestDB(t)
	router := setupRouter(t, db)
	dept := models.Department{Id: uuid.New(), Name: "IT"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	ledelseDept := models.Department{Id: uuid.New(), Name: "Ledelse"}
	if err := db.Create(&ledelseDept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		pendingID := uuid.New()
		req := httptest.NewRequest(http.MethodPut, "/users/"+pendingID.String()+"/approve", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("approving self returns 403", func(t *testing.T) {
		manager := models.User{
			Id:           uuid.New(),
			Name:         "Manager",
			Email:        "mgr3@test.com",
			PasswordHash: "x",
			DepartmentId: ledelseDept.Id,
		}
		manager.Department = ledelseDept
		if err := db.Create(&manager).Error; err != nil {
			t.Fatalf("create manager: %v", err)
		}

		req := httptest.NewRequest(http.MethodPut, "/users/"+manager.Id.String()+"/approve", nil)
		req = requestWithCurrentUser(req, &manager)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusForbidden {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusForbidden)
		}
	})

	t.Run("manager approves pending user returns 200", func(t *testing.T) {
		manager := models.User{
			Id:           uuid.New(),
			Name:         "Manager",
			Email:        "mgr4@test.com",
			PasswordHash: "x",
			DepartmentId: ledelseDept.Id,
		}
		manager.Department = ledelseDept
		if err := db.Create(&manager).Error; err != nil {
			t.Fatalf("create manager: %v", err)
		}

		pending := models.User{
			Id:           uuid.New(),
			Name:         "Pending",
			Email:        "pending@test.com",
			PasswordHash: "x",
			DepartmentId: dept.Id,
			IsApproved:   false,
		}
		if err := db.Create(&pending).Error; err != nil {
			t.Fatalf("create pending user: %v", err)
		}

		req := httptest.NewRequest(http.MethodPut, "/users/"+pending.Id.String()+"/approve", nil)
		req = requestWithCurrentUser(req, &manager)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.User
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if !got.IsApproved {
			t.Error("expected user to be approved")
		}
	})
}