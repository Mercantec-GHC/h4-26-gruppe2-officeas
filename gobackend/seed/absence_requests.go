package seed

import (
	"stuff/models"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedAbsenceRequests creates absence requests for seed users.
func SeedAbsenceRequests(db *gorm.DB) error {
	var users []models.User
	
	if err := db.Where("email IN ?", SeedUserEmails).Find(&users).Error; err != nil {
		return err
	}
	
	if len(users) < 2 {
		return nil
	}

	var shifts []models.Shift
	
	if err := db.Limit(2).Find(&shifts).Error; err != nil {
		return err
	}

	aliceID := findUserIDByEmail(users, "alice@seed.example.com")
	carolID := findUserIDByEmail(users, "carol@seed.example.com")
	
	if aliceID == uuid.Nil {
		return nil
	}

	baseStart := time.Date(2025, 2, 10, 0, 0, 0, 0, time.UTC)
	baseEnd := time.Date(2025, 2, 14, 0, 0, 0, 0, time.UTC)
	reviewedAt := time.Now().Add(-24 * time.Hour)

	requests := []models.AbsenceRequest{
		{
			Id:        uuid.New(),
			UserId:    aliceID,
			Type:      models.AbsenceTypeVacation,
			StartDate: baseStart,
			EndDate:   baseEnd,
			Status:    models.RequestStatusPending,
		},
		{
			Id:        uuid.New(),
			UserId:    aliceID,
			Type:      models.AbsenceTypeSickLeave,
			StartDate: baseStart.AddDate(0, 0, 20),
			EndDate:   baseEnd.AddDate(0, 0, 20),
			Status:    models.RequestStatusApproved,
			ReviewedAt: &reviewedAt,
			ReviewedByUserId: &carolID,
		},
	}

	if len(shifts) > 0 {
		requests = append(requests, models.AbsenceRequest{
			Id:        uuid.New(),
			UserId:    aliceID,
			Type:      models.AbsenceTypePersonal,
			StartDate: baseStart.AddDate(0, 0, 30),
			EndDate:   baseEnd.AddDate(0, 0, 30),
			ShiftId:   &shifts[0].Id,
			Status:    models.RequestStatusPending,
		})
	}

	for i := range requests {
		if err := db.Create(&requests[i]).Error; err != nil {
			return err
		}
	}

	return nil
}
