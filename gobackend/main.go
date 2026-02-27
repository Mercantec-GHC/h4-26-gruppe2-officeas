package main

import (
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"stuff/handlers"
	"stuff/internal/messaging"
	"stuff/internal/security"
	"stuff/models"

	_ "stuff/docs"

	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
	httpSwagger "github.com/swaggo/http-swagger"
	"golang.org/x/time/rate"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// @title           YourOffice API
// @host            localhost:8080
// @BasePath        /api
// @securityDefinitions.apikey BearerAuth
// @in              header
// @name            Authorization

func runMigrations(db *gorm.DB) error {
	// AutoMigrate will create tables if they don't exist, or update schema if models changed
	// It will NOT drop existing tables or data

	if err := db.AutoMigrate(
		&models.Department{},
		&models.User{},
		&models.Ticket{},
		&models.TicketComment{},
		&models.Feedback{},
		&models.Shift{},
		&models.AbsenceRequest{},
		&models.AbsenceRequestComment{},
		&models.Notification{},
		// Messaging module
		&models.Conversation{},
		&models.ConversationMember{},
		&models.Message{},
		&models.DeviceToken{},
	); err != nil {
		return err
	}

	if err := db.Exec(`
		ALTER TABLE users
		ALTER COLUMN is_approved SET DEFAULT FALSE
	`).Error; err != nil {
		return err
	}

	if err := db.Exec(`
		UPDATE users
		SET is_approved = FALSE
		WHERE is_approved IS NULL
	`).Error; err != nil {
		return err
	}

	return nil
}

// allowedOrigins defines the production origins permitted for CORS.
var allowedOrigins = map[string]bool{
	"https://h4-flutter.mercantec.tech": true,
	"https://h4-api.mercantec.tech":     true,
}

// isAllowedOrigin returns true for any localhost origin (any port, for dev)
// and for explicitly listed production origins.
func isAllowedOrigin(origin string) bool {
	if allowedOrigins[origin] {
		return true
	}
	// Allow any localhost port (Flutter web debug uses a random port)
	if strings.HasPrefix(origin, "http://localhost:") || strings.HasPrefix(origin, "http://127.0.0.1:") {
		return true
	}
	return false
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && isAllowedOrigin(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Vary", "Origin")
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

	// Auth routes with rate limiting (nginx strips /api so backend receives /auth/...)
	authRouter := router.PathPrefix("/auth").Subrouter()
	authRouter.Use(rateLimiter.RateLimitMiddleware)
	handlers.RegisterAuth(authRouter, handlers.Auth{DB: db}, "")

	// Protected routes (no /api prefix; nginx strips /api so backend receives /departments, /users, etc.)
	protectedRouter := router.PathPrefix("").Subrouter()
	protectedRouter.Use(handlers.AuthMiddleware)
	handlers.SetAuthorizationService(db)

	// Upload directory for profile and ticket images (default ./uploads)
	uploadDir := os.Getenv("UPLOAD_DIR")
	
	if uploadDir == "" {
		uploadDir = "./uploads"
	}

	// Departments (protected)
	// Feedback CRUD -> POST /feedback (auth via middleware on same router)
	handlers.RegisterFeedback(protectedRouter, handlers.Feedback{DB: db}, "/feedback")

	// Departments (protected) -> GET/POST /departments
	handlers.RegisterDepartments(protectedRouter, handlers.Departments{DB: db}, "/departments")

	// Users CRUD (protected) + profile image upload/serve
	handlers.RegisterUsers(protectedRouter, handlers.Users{DB: db, UploadDir: uploadDir}, "/users")

	// Tickets CRUD (protected) + ticket image upload/serve
	handlers.RegisterTickets(protectedRouter, handlers.Tickets{DB: db, UploadDir: uploadDir}, "/tickets")

	// Shifts CRUD (protected)
	handlers.RegisterShifts(protectedRouter, handlers.Shifts{DB: db}, "/shifts")

	// Absence requests CRUD (protected)
	handlers.RegisterAbsenceRequests(protectedRouter, handlers.AbsenceRequests{DB: db}, "/absence-requests")

	// Ticket comments (protected)
	handlers.RegisterTicketComments(protectedRouter, handlers.TicketComments{DB: db}, "/tickets", "/ticket-comments")

	// Absence request comments (protected)
	handlers.RegisterAbsenceRequestComments(protectedRouter, handlers.AbsenceRequestComments{DB: db}, "/absence-requests", "/absence-request-comments")

	// Notifications (protected)
	handlers.RegisterNotifications(protectedRouter, handlers.Notifications{DB: db}, "/notifications")

	// -----------------------------------------------------------------------
	// Messaging module (encrypted, WebSocket-enabled internal messaging)
	// -----------------------------------------------------------------------
	encryptor, err := security.NewEncryptorFromBase64(os.Getenv("MESSAGE_ENCRYPTION_KEY"))
	if err != nil {
		log.Printf("WARNING: Message encryption not available: %v", err)
		log.Printf("Set MESSAGE_ENCRYPTION_KEY (base64, 32 bytes) to enable messaging")
	}

	if encryptor != nil {
		// Rate limiter: 10 messages per 5 seconds (2/s sustained, burst 10)
		msgRateLimiter := messaging.NewMessageRateLimiter(rate.Limit(2), 10)
		auditLogger := messaging.NewAuditLogger()
		notifier := &messaging.NoopNotificationSender{}

		msgService := messaging.NewService(db, encryptor, msgRateLimiter, auditLogger, notifier)
		msgHub := messaging.NewHub(msgService, auditLogger)
		msgService.SetHub(msgHub)

		// Start the hub's event loop in a background goroutine
		go msgHub.Run()

		msgHandler := handlers.Messaging{Service: msgService, Hub: msgHub}
		handlers.RegisterMessaging(protectedRouter, router, msgHandler)
		println("Messaging module initialised")
	}

	handler := corsMiddleware(router)

	// Bind to 0.0.0.0 to accept connections from both localhost and 127.0.0.1
	addr := "0.0.0.0:8080"
	println("Server running on http://127.0.0.1:8080")
	if err := http.ListenAndServe(addr, handler); err != nil {
		panic(err)
	}
}
