// Package seed provides database seeders for all entities.
// Seed is idempotent for departments (by name) and users (by email).
// Child entities (tickets, comments, feedback, shifts, absence requests, notifications) are always seeded; re-running adds more rows.
//
// Seed users all use the same password for development login:
//   Password: Seeder123!
package seed

import (
	"fmt"

	"gorm.io/gorm"
)

// Run executes all seed steps in dependency order.
// Requires DB to have migrations applied (tables exist).
func Run(db *gorm.DB) error {
	steps := []struct {
		name string
		fn   func(*gorm.DB) error
	}{
		{"departments", SeedDepartments},
		{"users", SeedUsers},
		{"tickets", SeedTickets},
		{"feedback", SeedFeedback},
		{"shifts", SeedShifts},
		{"ticket_comments", SeedTicketComments},
		{"absence_requests", SeedAbsenceRequests},
		{"absence_request_comments", SeedAbsenceRequestComments},
		{"notifications", SeedNotifications},
	}

	for _, step := range steps {
		if err := step.fn(db); err != nil {
			return fmt.Errorf("seed %s: %w", step.name, err)
		}
	}

	return nil
}
