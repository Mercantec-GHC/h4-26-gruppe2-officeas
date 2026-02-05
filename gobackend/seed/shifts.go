package seed

import (
	"stuff/models"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedShifts creates shifts for seed users.
func SeedShifts(db *gorm.DB) error {
	var users []models.User
	
	if err := db.Where("email IN ?", SeedUserEmails).Find(&users).Error; err != nil {
		return err
	}
	
	if len(users) == 0 {
		return nil
	}

	// Create a week of shifts: morning 09:00-17:00 for first two users
	loc := time.UTC
	baseDate := time.Date(2025, 1, 6, 0, 0, 0, 0, loc) // Monday

	for u := 0; u < 2 && u < len(users); u++ {
		for day := 0; day < 5; day++ {
			start := baseDate.AddDate(0, 0, day).Add(9 * time.Hour)
			end := baseDate.AddDate(0, 0, day).Add(17 * time.Hour)
			shift := models.Shift{
				Id:        uuid.New(),
				UserId:    users[u].Id,
				StartTime: start,
				EndTime:   end,
			}
	
			if err := db.Create(&shift).Error; err != nil {
				return err
			}
		}
	}

	return nil
}
