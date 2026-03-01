package handlers

import (
	"bytes"
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

func setupTicketsTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.Department{}, &models.Ticket{}, &models.TicketComment{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	SetAuthorizationService(db)
	return db
}

func setupTicketsRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := Tickets{DB: db}
	RegisterTickets(router, h, "/tickets")
	return router
}

func TestTickets_List(t *testing.T) {
	db := setupTicketsTestDB(t)
	router := setupTicketsRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/tickets", nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("with user returns 200 and list", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT-Support"}
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
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/tickets", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.Ticket
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})
}

func TestTickets_GetByID(t *testing.T) {
	db := setupTicketsTestDB(t)
	router := setupTicketsRouter(t, db)

	t.Run("invalid UUID returns 400", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT-Support"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u-invalid@t.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}
		req := httptest.NewRequest(http.MethodGet, "/tickets/not-a-uuid", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
		}
	})

	t.Run("missing ticket returns 403", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT-Support"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u-missing@t.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}
		req := httptest.NewRequest(http.MethodGet, "/tickets/"+uuid.New().String(), nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		// Middleware returns 403 when ticket not found (to avoid leaking existence)
		if rec.Code != http.StatusForbidden {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusForbidden)
		}
	})

	t.Run("existing ticket returns 200", func(t *testing.T) {
		dept := models.Department{Id: uuid.New(), Name: "IT-Support"}
		if err := db.Create(&dept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}
		user := models.User{Id: uuid.New(), Name: "U", Email: "u-existing@t.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		ticket := models.Ticket{
			Id:              uuid.New(),
			Title:           "Test",
			Description:     "Desc",
			Status:          models.TicketStatusOpen,
			CreatedByUserId: user.Id,
		}
		if err := db.Create(&ticket).Error; err != nil {
			t.Fatalf("create ticket: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/tickets/"+ticket.Id.String(), nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var got models.Ticket
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Title != "Test" {
			t.Errorf("got %+v", got)
		}
	})
}

func TestTickets_Create(t *testing.T) {
	db := setupTicketsTestDB(t)
	router := setupTicketsRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "IT-Support"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	user := models.User{Id: uuid.New(), Name: "U", Email: "u@t.com", PasswordHash: "x", DepartmentId: dept.Id}
	user.Department = dept
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		body := []byte(`{"title":"T","description":"D"}`)
		req := httptest.NewRequest(http.MethodPost, "/tickets", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("creates ticket and returns 201", func(t *testing.T) {
		body := []byte(`{"title":"New Ticket","description":"Description"}`)
		req := httptest.NewRequest(http.MethodPost, "/tickets", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}

		var got models.Ticket
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Title != "New Ticket" || got.CreatedByUserId != user.Id {
			t.Errorf("got %+v", got)
		}
	})

	t.Run("user from unmapped department can create ticket", func(t *testing.T) {
		unknownDept := models.Department{Id: uuid.New(), Name: "Lager"}
		if err := db.Create(&unknownDept).Error; err != nil {
			t.Fatalf("create department: %v", err)
		}

		unknownDeptUser := models.User{
			Id:           uuid.New(),
			Name:         "Unknown Dept User",
			Email:        "unknown-dept@t.com",
			PasswordHash: "x",
			DepartmentId: unknownDept.Id,
		}
		unknownDeptUser.Department = unknownDept
		if err := db.Create(&unknownDeptUser).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}

		body := []byte(`{"title":"Ticket from unknown dept","description":"Description"}`)
		req := httptest.NewRequest(http.MethodPost, "/tickets", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &unknownDeptUser)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}
	})
}
