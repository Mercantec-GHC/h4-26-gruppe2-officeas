package main

import (
	"net/http"
	"os"

	"stuff/handlers"
	"stuff/models"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
	httpSwagger "github.com/swaggo/http-swagger"
	_ "stuff/docs"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// @title           YourOffice API
// @host      localhost:8080
// @BasePath  /api

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

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
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

	router := mux.NewRouter()

	// Health
	router.HandleFunc("/health", handlers.Health).Methods("GET")

	// Departments (list + create only)
	handlers.RegisterDepartments(router, handlers.Departments{DB: db}, "/departments")

	// Users CRUD
	handlers.RegisterUsers(router, handlers.Users{DB: db}, "/users")

	// Tickets CRUD
	handlers.RegisterTickets(router, handlers.Tickets{DB: db}, "/tickets")

	// Shifts CRUD
	handlers.RegisterShifts(router, handlers.Shifts{DB: db}, "/shifts")

	// Absence requests CRUD
	handlers.RegisterAbsenceRequests(router, handlers.AbsenceRequests{DB: db}, "/absence-requests")

	// Ticket comments (nested + by id)
	handlers.RegisterTicketComments(router, handlers.TicketComments{DB: db}, "/tickets", "/ticket-comments")

	// Absence request comments (nested + by id)
	handlers.RegisterAbsenceRequestComments(router, handlers.AbsenceRequestComments{DB: db}, "/absence-requests", "/absence-request-comments")

	// Swagger doc.json
	router.HandleFunc("/swagger/doc.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		http.ServeFile(w, r, "./docs/swagger.json")
	}).Methods("GET")

	// Swagger UI
	router.PathPrefix("/swagger/").Handler(httpSwagger.WrapHandler)

	handler := corsMiddleware(router)

	port := ":8080"
	println("Server running on http://localhost:8080")
	if err := http.ListenAndServe(port, handler); err != nil {
		panic(err)
	}
}
