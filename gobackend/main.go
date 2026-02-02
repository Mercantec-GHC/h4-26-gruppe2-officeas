package main

import (
	"net/http"
	"os"
	"time"

	"stuff/handlers"
	"stuff/models"

	_ "stuff/docs"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
	httpSwagger "github.com/swaggo/http-swagger"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// @title           YourOffice API
// @host      localhost:8080
// @BasePath  /api

func runMigrations(db *gorm.DB) error {
	// AutoMigrate will create tables if they don't exist, or update schema if models changed
	// It will NOT drop existing tables or data

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

	// Rate limiter - 100 requests per minute per IP
	rateLimiter := handlers.NewRateLimiter(100, 1*time.Minute)
	rateLimiter.Cleanup() // Start cleanup routine

	// Public routes (no auth required)
	publicRouter := router.PathPrefix("").Subrouter()
	publicRouter.HandleFunc("/health", handlers.Health).Methods("GET")
	publicRouter.PathPrefix("/swagger/").Handler(httpSwagger.WrapHandler)
	publicRouter.HandleFunc("/swagger/doc.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		http.ServeFile(w, r, "./docs/swagger.json")
	}).Methods("GET")

	// Auth routes with rate limiting
	authRouter := router.PathPrefix("/auth").Subrouter()
	authRouter.Use(rateLimiter.RateLimitMiddleware)
	handlers.RegisterAuth(authRouter, handlers.Auth{DB: db}, "")

	// Protected routes (require authentication)
	protectedRouter := router.PathPrefix("").Subrouter()
	protectedRouter.Use(handlers.AuthMiddleware)

	// Departments (protected)
	handlers.RegisterDepartments(protectedRouter, handlers.Departments{DB: db}, "/departments")

	// Users CRUD (protected)
	handlers.RegisterUsers(protectedRouter, handlers.Users{DB: db}, "/users")

	// Tickets CRUD (protected)
	handlers.RegisterTickets(protectedRouter, handlers.Tickets{DB: db}, "/tickets")

	// Shifts CRUD (protected)
	handlers.RegisterShifts(protectedRouter, handlers.Shifts{DB: db}, "/shifts")

	// Absence requests CRUD (protected)
	handlers.RegisterAbsenceRequests(protectedRouter, handlers.AbsenceRequests{DB: db}, "/absence-requests")

	// Ticket comments (protected)
	handlers.RegisterTicketComments(protectedRouter, handlers.TicketComments{DB: db}, "/tickets", "/ticket-comments")

	// Absence request comments (protected)
	handlers.RegisterAbsenceRequestComments(protectedRouter, handlers.AbsenceRequestComments{DB: db}, "/absence-requests", "/absence-request-comments")

	handler := corsMiddleware(router)

	// Bind to 0.0.0.0 to accept connections from both localhost and 127.0.0.1
	addr := "0.0.0.0:8080"
	println("Server running on http://127.0.0.1:8080")
	if err := http.ListenAndServe(addr, handler); err != nil {
		panic(err)
	}
}
