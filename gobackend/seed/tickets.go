package seed

import (
	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedTicketTitlePrefix marks seed tickets.
const SeedTicketTitlePrefix = "Seed: "

// SeedTickets creates a few tickets from seed users.
func SeedTickets(db *gorm.DB) error {
	var users []models.User
	
	if err := db.Where("email IN ?", SeedUserEmails).Find(&users).Error; err != nil {
		return err
	}
	
	if len(users) < 2 {
		return nil
	}

	var aliceID, bobID uuid.UUID
	
	for i := range users {
		if users[i].Email == "alice@seed.example.com" {
			aliceID = users[i].Id
		}
	
		if users[i].Email == "bob@seed.example.com" {
			bobID = users[i].Id
		}
	}
	
	if aliceID == uuid.Nil || bobID == uuid.Nil {
		return nil
	}

	tickets := []models.Ticket{
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Office printer not working",
			Description:      "The printer on floor 2 is jammed and shows error code E3.",
			Status:           models.TicketStatusOpen,
			CreatedByUserId:  aliceID,
			AssignedToUserId: &bobID,
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "VPN access request",
			Description:      "Need VPN credentials for remote work.",
			Status:           models.TicketStatusInProgress,
			CreatedByUserId:  aliceID,
			AssignedToUserId: &bobID,
		},
		{
			Id:              uuid.New(),
			Title:           SeedTicketTitlePrefix + "New monitor setup",
			Description:     "Request for a second monitor at desk.",
			Status:          models.TicketStatusResolved,
			CreatedByUserId: bobID,
		},
	}

	for i := range tickets {
		if err := db.Create(&tickets[i]).Error; err != nil {
			return err
		}
	}

	return nil
}
