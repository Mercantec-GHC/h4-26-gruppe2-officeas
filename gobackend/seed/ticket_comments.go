package seed

import (
	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedTicketComments creates comments on seed tickets.
func SeedTicketComments(db *gorm.DB) error {
	var tickets []models.Ticket

	if err := db.Where("title LIKE ?", SeedTicketTitlePrefix+"%").Find(&tickets).Error; err != nil {
		return err
	}
	
	if len(tickets) == 0 {
		return nil
	}

	var users []models.User
	if err := db.Limit(10).Find(&users).Error; err != nil {
		return err
	}
	
	if len(users) < 2 {
		return nil
	}

	// Add one comment per ticket (alternating users)
	for i, t := range tickets {
		commenterID := users[i%2].Id
	
		c := models.TicketComment{
			Id:        uuid.New(),
			TicketId:  t.Id,
			UserId:    commenterID,
			Content:   "Seed comment: following up on this ticket.",
		}
	
		if err := db.Create(&c).Error; err != nil {
			return err
		}
	}

	return nil
}
