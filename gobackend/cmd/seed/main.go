package main

import (
	"fmt"
	"os"

	"stuff/models"
	"stuff/seed"

	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func runMigrations(db *gorm.DB) error {
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
		fmt.Fprintln(os.Stderr, "DATABASE_URL environment variable not set")
		os.Exit(1)
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to connect to database: %v\n", err)
		os.Exit(1)
	}

	if err := runMigrations(db); err != nil {
		fmt.Fprintf(os.Stderr, "failed to run migrations: %v\n", err)
		os.Exit(1)
	}

	if err := seed.Run(db); err != nil {
		fmt.Fprintf(os.Stderr, "seed failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Seed completed successfully.")
}
