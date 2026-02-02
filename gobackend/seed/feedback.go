package seed

import (
	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedFeedback creates feedback entries per department.
func SeedFeedback(db *gorm.DB) error {
	var departments []models.Department
	
	if err := db.Find(&departments).Error; err != nil {
		return err
	}

	for _, dept := range departments {
		for _, rating := range []int{4, 5, 5} {
			fb := models.Feedback{
				Id:           uuid.New(),
				DepartmentId: dept.Id,
				Rating:       rating,
			}
	
			if err := db.Create(&fb).Error; err != nil {
				return err
			}
		}
	}

	return nil
}
