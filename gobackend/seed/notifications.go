package seed

import (
	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedNotifications creates notifications for seed users.
func SeedNotifications(db *gorm.DB) error {
	var users []models.User
	
	if err := db.Where("email IN ?", SeedUserEmails).Find(&users).Error; err != nil {
		return err
	}
	
	if len(users) == 0 {
		return nil
	}

	userID := users[0].Id
	ticketType := models.NotificationTypeTicketAssigned
	notifications := []models.Notification{
		{
			Id:        uuid.New(),
			UserId:    userID,
			Title:     "Seed: Ticket assigned",
			Message:   "You have been assigned a seed ticket.",
			Type:      ticketType,
		},
		{
			Id:        uuid.New(),
			UserId:    userID,
			Title:     "Seed: System announcement",
			Message:   "This is a seed system announcement for development.",
			Type:      models.NotificationTypeSystemAnnouncement,
		},
	}

	for i := range notifications {
		if err := db.Create(&notifications[i]).Error; err != nil {
			return err
		}
	}

	return nil
}
