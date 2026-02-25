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

func setupTicketCommentsTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.Department{}, &models.Ticket{}, &models.TicketComment{}, &models.Notification{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	SetAuthorizationService(db)
	return db
}

func setupTicketCommentsRouter(t *testing.T, db *gorm.DB) *mux.Router {
	router := mux.NewRouter()
	h := TicketComments{DB: db}
	RegisterTicketComments(router, h, "/tickets", "/ticket-comments")
	return router
}

func TestTicketComments_ListByTicket(t *testing.T) {
	db := setupTicketCommentsTestDB(t)
	router := setupTicketCommentsRouter(t, db)

	t.Run("no current user returns 401", func(t *testing.T) {
		ticketID := uuid.New()
		req := httptest.NewRequest(http.MethodGet, "/tickets/"+ticketID.String()+"/comments", nil)
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
		user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
		user.Department = dept
		if err := db.Create(&user).Error; err != nil {
			t.Fatalf("create user: %v", err)
		}
		ticket := models.Ticket{
			Id:              uuid.New(),
			Title:           "T",
			Description:     "D",
			Status:          models.TicketStatusOpen,
			CreatedByUserId: user.Id,
		}
		if err := db.Create(&ticket).Error; err != nil {
			t.Fatalf("create ticket: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/tickets/"+ticket.Id.String()+"/comments", nil)
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
		}

		var list []models.TicketComment
		if err := json.NewDecoder(rec.Body).Decode(&list); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if len(list) != 0 {
			t.Errorf("len(list) = %d, want 0", len(list))
		}
	})
}

func TestTicketComments_CreateOnTicket(t *testing.T) {
	db := setupTicketCommentsTestDB(t)
	router := setupTicketCommentsRouter(t, db)

	dept := models.Department{Id: uuid.New(), Name: "IT-Support"}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	user := models.User{Id: uuid.New(), Name: "U", Email: "u@test.com", PasswordHash: "x", DepartmentId: dept.Id}
	user.Department = dept
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	ticket := models.Ticket{
		Id:              uuid.New(),
		Title:           "T",
		Description:     "D",
		Status:          models.TicketStatusOpen,
		CreatedByUserId: user.Id,
	}
	if err := db.Create(&ticket).Error; err != nil {
		t.Fatalf("create ticket: %v", err)
	}

	t.Run("no current user returns 401", func(t *testing.T) {
		body := []byte(`{"user_id":"` + user.Id.String() + `","content":"A comment"}`)
		req := httptest.NewRequest(http.MethodPost, "/tickets/"+ticket.Id.String()+"/comments", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("creates comment and returns 201", func(t *testing.T) {
		body := []byte(`{"user_id":"` + user.Id.String() + `","content":"A comment"}`)
		req := httptest.NewRequest(http.MethodPost, "/tickets/"+ticket.Id.String()+"/comments", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req = requestWithCurrentUser(req, &user)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("status = %d, want %d", rec.Code, http.StatusCreated)
		}

		var got models.TicketComment
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Fatalf("decode: %v", err)
		}
		if got.Content != "A comment" || got.TicketId != ticket.Id {
			t.Errorf("got %+v", got)
		}
	})
}
