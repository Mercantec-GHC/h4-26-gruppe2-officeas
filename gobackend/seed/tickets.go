package seed

import (
	"stuff/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SeedTicketTitlePrefix marks seed tickets.
const SeedTicketTitlePrefix = "Seed: "

// SeedTickets creates seed tickets from seed users.
func SeedTickets(db *gorm.DB) error {
	var users []models.User
	if err := db.Limit(15).Find(&users).Error; err != nil {
		return err
	}
	if len(users) < 2 {
		return nil
	}

	var deptITSupport models.Department
	if err := db.Where("name = ?", "IT-Support").First(&deptITSupport).Error; err != nil {
		return err
	}
	var itSupportUsers []models.User
	if err := db.Where("department_id = ?", deptITSupport.Id).Find(&itSupportUsers).Error; err != nil {
		return err
	}

	// Creators: any user. Assignees: only IT-Support (cycle by index), or nil for unassigned.
	creator := func(i int) uuid.UUID { return users[i%len(users)].Id }
	assignee := func(i int) *uuid.UUID {
		if len(itSupportUsers) == 0 {
			return nil
		}
		id := itSupportUsers[i%len(itSupportUsers)].Id
		return &id
	}

	// unassigned: ticket has no assignee (nil). Use for a few OPEN / new tickets.
	unassigned := []bool{
		true,  // 0  - Office printer
		false, // 1  - VPN
		true,  // 2  - New monitor
		false, // 3  - Keyboard
		false, // 4  - Email client
		true,  // 5  - Meeting room projector
		false, // 6  - Software license
		false, // 7  - Wi-Fi
		false, // 8  - Access card
		false, // 9  - Docking station
		true,  // 10 - Shared drive
		false, // 11 - Password reset
		true,  // 12 - Duplicate (cancelled, no assignee)
		false, // 13 - Phone voicemail
		false, // 14 - Antivirus
	}

	tickets := []models.Ticket{
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Office printer not working",
			Description:      "The printer on floor 2 is jammed and shows error code E3.",
			Status:           models.TicketStatusOpen,
			CreatedByUserId:  creator(0),
			AssignedToUserId: orNil(!unassigned[0], assignee(0)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "VPN access request",
			Description:      "Need VPN credentials for remote work.",
			Status:           models.TicketStatusInProgress,
			CreatedByUserId:  creator(1),
			AssignedToUserId: orNil(!unassigned[1], assignee(1)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "New monitor setup",
			Description:      "Request for a second monitor at desk.",
			Status:           models.TicketStatusResolved,
			CreatedByUserId:  creator(2),
			AssignedToUserId: orNil(!unassigned[2], assignee(2)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Keyboard replacement",
			Description:      "Several keys on my keyboard are unresponsive. Requesting a replacement.",
			Status:           models.TicketStatusOpen,
			CreatedByUserId:  creator(3),
			AssignedToUserId: orNil(!unassigned[3], assignee(3)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Email client configuration",
			Description:      "Need help setting up Outlook with the new exchange server.",
			Status:           models.TicketStatusInProgress,
			CreatedByUserId:  creator(4),
			AssignedToUserId: orNil(!unassigned[4], assignee(4)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Meeting room projector",
			Description:      "Projector in room 3B is not turning on. Checked power and cables.",
			Status:           models.TicketStatusOpen,
			CreatedByUserId:  creator(5),
			AssignedToUserId: orNil(!unassigned[5], assignee(5)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Software license renewal",
			Description:      "Adobe Creative Cloud license expires next month. Please renew.",
			Status:           models.TicketStatusResolved,
			CreatedByUserId:  creator(6),
			AssignedToUserId: orNil(!unassigned[6], assignee(6)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Wi‑Fi drops in building B",
			Description:      "Intermittent connection loss on the second floor, building B.",
			Status:           models.TicketStatusOpen,
			CreatedByUserId:  creator(7),
			AssignedToUserId: orNil(!unassigned[7], assignee(7)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Access card not working",
			Description:      "My access card was deactivated after the weekend. Need reactivation.",
			Status:           models.TicketStatusInProgress,
			CreatedByUserId:  creator(8),
			AssignedToUserId: orNil(!unassigned[8], assignee(8)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Docking station USB issues",
			Description:      "USB ports on the docking station only work after replugging the dock.",
			Status:           models.TicketStatusClosed,
			CreatedByUserId:  creator(9),
			AssignedToUserId: orNil(!unassigned[9], assignee(9)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Shared drive permissions",
			Description:      "Need read/write access to the Marketing shared drive.",
			Status:           models.TicketStatusOpen,
			CreatedByUserId:  creator(10),
			AssignedToUserId: orNil(!unassigned[10], assignee(10)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Password reset request",
			Description:      "Locked out of my account after too many failed attempts.",
			Status:           models.TicketStatusResolved,
			CreatedByUserId:  creator(11),
			AssignedToUserId: orNil(!unassigned[11], assignee(11)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Duplicate request",
			Description:      "Created by mistake; same issue already reported in ticket #42.",
			Status:           models.TicketStatusCancelled,
			CreatedByUserId:  creator(12),
			AssignedToUserId: orNil(!unassigned[12], assignee(12)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Phone system voicemail",
			Description:      "Voicemail greeting needs to be updated and mailbox full.",
			Status:           models.TicketStatusOpen,
			CreatedByUserId:  creator(13),
			AssignedToUserId: orNil(!unassigned[13], assignee(13)),
		},
		{
			Id:               uuid.New(),
			Title:            SeedTicketTitlePrefix + "Antivirus scan blocking PC",
			Description:      "Scheduled scan runs during work hours and freezes the machine.",
			Status:           models.TicketStatusInProgress,
			CreatedByUserId:  creator(14),
			AssignedToUserId: orNil(!unassigned[14], assignee(14)),
		},
	}

	for i := range tickets {
		if err := db.Create(&tickets[i]).Error; err != nil {
			return err
		}
	}

	return nil
}

// orNil returns nil if use is false, otherwise id (for optional assignee).
func orNil(use bool, id *uuid.UUID) *uuid.UUID {
	if !use {
		return nil
	}
	return id
}
