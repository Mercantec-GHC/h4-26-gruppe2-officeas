package seed

import (
	"time"

	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedDepartments creates IT, HR, and Sales departments if they do not exist.
// Idempotent: skips creation when a department with the same name exists.
func SeedDepartments(db *gorm.DB) error {
	names := []string{"IT", "HR", "Sales"}
	now := time.Now()

	for _, name := range names {
		var existing models.Department
		if err := db.Where("name = ?", name).First(&existing).Error; err == nil {
			continue // already exists
		}

		dept := models.Department{
			Id:        uuid.New(),
			Name:      name,
			CreatedAt: now,
			UpdatedAt: now,
		}
		if err := db.Create(&dept).Error; err != nil {
			return err
		}
	}

	return nil
}
