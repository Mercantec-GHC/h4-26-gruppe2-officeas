package main

import (
	"encoding/json"
	"net/http"
	"os"

	"stuff/models"

	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func runMigrations(db *gorm.DB) error {
	// Drop all tables in reverse order of dependencies to avoid constraint errors
	_ = db.Migrator().DropTable(
		&models.Notification{},
		&models.AbsenceRequestComment{},
		&models.AbsenceRequest{},
		&models.TicketComment{},
		&models.Ticket{},
		&models.Feedback{},
		&models.Shift{},
		&models.User{},
		&models.Department{},
	)

	// Create fresh tables with correct schema
	return db.AutoMigrate(
		&models.Department{},
		&models.User{},
		&models.Ticket{},
		&models.TicketComment{},
		&models.Feedback{},
		&models.Shift{},
		&models.AbsenceRequest{},
		&models.AbsenceRequestComment{},
		&models.Notification{},
	)
}

func main() {
	_ = godotenv.Load()

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		panic("DATABASE_URL environment variable not set")
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		panic("failed to connect to database: " + err.Error())
	}

	if err := runMigrations(db); err != nil {
		panic("failed to run migrations: " + err.Error())
	}

	println("Migrations applied successfully")

	// CORS middleware
	corsMiddleware := func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

			// Handle preflight requests
			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next(w, r)
		}
	}

	// Setup HTTP routes with CORS
	http.HandleFunc("/health", corsMiddleware(healthHandler))
	http.HandleFunc("/departments", corsMiddleware(departmentsHandler(db)))
	http.HandleFunc("/departments/create", corsMiddleware(createDepartmentHandler(db)))
	http.HandleFunc("/users", corsMiddleware(usersHandler(db)))
	http.HandleFunc("/users/create", corsMiddleware(createUserHandler(db)))
	http.HandleFunc("/tickets", corsMiddleware(ticketsHandler(db)))
	http.HandleFunc("/tickets/create", corsMiddleware(createTicketHandler(db)))

	port := ":8080"
	println("Server running on http://localhost:8080")
	if err := http.ListenAndServe(port, nil); err != nil {
		panic(err)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func departmentsHandler(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var departments []models.Department
		if err := db.Find(&departments).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(departments)
	}
}

func createDepartmentHandler(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var dept models.Department
		if err := json.NewDecoder(r.Body).Decode(&dept); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		dept.Id = uuid.New()
		if err := db.Create(&dept).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(dept)
	}
}

func usersHandler(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var users []models.User
		if err := db.Preload("Department").Find(&users).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(users)
	}
}

func createUserHandler(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var user models.User
		if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		user.Id = uuid.New()
		if err := db.Create(&user).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(user)
	}
}

func ticketsHandler(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var tickets []models.Ticket
		if err := db.Preload("CreatedByUser").Preload("AssignedToUser").Preload("Comments").Find(&tickets).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tickets)
	}
}

func createTicketHandler(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var ticket models.Ticket
		if err := json.NewDecoder(r.Body).Decode(&ticket); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		ticket.Id = uuid.New()
		ticket.Status = models.TicketStatusOpen
		if err := db.Create(&ticket).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(ticket)
	}
}
