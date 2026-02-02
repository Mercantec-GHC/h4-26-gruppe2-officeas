package seed

import (
	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedAbsenceRequestComments creates comments on seed absence requests.
func SeedAbsenceRequestComments(db *gorm.DB) error {
	var requests []models.AbsenceRequest
	
	if err := db.Find(&requests).Error; err != nil {
		return err
	}
	
	if len(requests) == 0 {
		return nil
	}

	var users []models.User
	
	if err := db.Where("email IN ?", SeedUserEmails).Find(&users).Error; err != nil {
		return err
	}
	
	if len(users) == 0 {
		return nil
	}

	commenterID := users[0].Id
	
	for _, ar := range requests {
		c := models.AbsenceRequestComment{
			Id:               uuid.New(),
			AbsenceRequestId: ar.Id,
			UserId:           commenterID,
			Content:          "Seed comment: noted for records.",
		}
	
		if err := db.Create(&c).Error; err != nil {
			return err
		}
	}

	return nil
}
