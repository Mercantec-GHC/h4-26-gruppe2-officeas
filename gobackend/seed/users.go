package seed

import (
	"fmt"
	"stuff/models"
	"time"

	"github.com/go-faker/faker/v4"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// SeedPassword is the password for all faker-seeded users (development only).
// Documented here so devs can log in: Seeder123!
const SeedPassword = "Seeder123!"

// SeedFakeUserCount is the number of additional users to create with faker (on top of the Mercantec Test user).
const SeedFakeUserCount = 80

const mercantecTestEmail = "mercantec@mercantec.dk"
const mercantecTestPassword = "Password123!"

// E2E manager (Ledelse) for e2e tests that create/update/delete users.
const E2EManagerEmail = "e2e-manager@test.com"
const E2EManagerPassword = "Password123!"

// fakeUser is used with go-faker to generate name and email.
type fakeUser struct {
	FirstName string `faker:"first_name"`
	LastName  string `faker:"last_name"`
	Email     string `faker:"email"`
}

// SeedUsers creates seed users if they do not exist.
// First creates the Mercantec Test user (IT-Support department); then creates SeedFakeUserCount
// users with go-faker assigned to random departments. Idempotent: skips when email exists.
func SeedUsers(db *gorm.DB) error {
	var departments []models.Department
	if err := db.Find(&departments).Error; err != nil || len(departments) == 0 {
		return err
	}

	var deptITSupport models.Department
	if err := db.Where("name = ?", "IT-Support").First(&deptITSupport).Error; err != nil {
		return err
	}

	// Mercantec Test user (IT-Support department)
	{
		var existing models.User
		if err := db.Where("email = ?", mercantecTestEmail).First(&existing).Error; err != nil {
			hashed, err := bcrypt.GenerateFromPassword([]byte(mercantecTestPassword), bcrypt.DefaultCost)

			if err != nil {
				return err
			}

			user := models.User{
				Id:           uuid.New(),
				Name:         "Mercantec Test",
				Email:        mercantecTestEmail,
				PasswordHash: string(hashed),
				DepartmentId: deptITSupport.Id,
				IsApproved:   true,
				ApprovedAt:   func() *time.Time { now := time.Now(); return &now }(),
			}

			if err := db.Create(&user).Error; err != nil {
				return err
			}
		}
	}

	var deptLedelse models.Department
	if err := db.Where("name = ?", "Ledelse").First(&deptLedelse).Error; err != nil {
		return err
	}

	// E2E manager user (Ledelse) for e2e tests that create/update/delete users.
	{
		var existing models.User
		if err := db.Where("email = ?", E2EManagerEmail).First(&existing).Error; err != nil {
			hashed, err := bcrypt.GenerateFromPassword([]byte(E2EManagerPassword), bcrypt.DefaultCost)
			
			if err != nil {
				return err
			}

			user := models.User{
				Id:           uuid.New(),
				Name:         "E-E Manager",
				Email:        E2EManagerEmail,
				PasswordHash: string(hashed),
				DepartmentId: deptLedelse.Id,
				IsApproved:   true,
				ApprovedAt:   func() *time.Time { now := time.Now(); return &now }(),
			}
			
			if err := db.Create(&user).Error; err != nil {
				return err
			}
		}
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(SeedPassword), bcrypt.DefaultCost)

	if err != nil {
		return err
	}

	// Faker-generated users (random departments)
	seenEmails := map[string]struct{}{mercantecTestEmail: {}, E2EManagerEmail: {}}

	for i := 0; i < SeedFakeUserCount; i++ {
		var fu fakeUser

		if err := faker.FakeData(&fu); err != nil {
			return err
		}

		if _, ok := seenEmails[fu.Email]; ok {
			i-- // retry this slot
			continue
		}

		seenEmails[fu.Email] = struct{}{}

		var existing models.User

		if err := db.Where("email = ?", fu.Email).First(&existing).Error; err == nil {
			continue
		}

		deptIdx := i % len(departments)
		user := models.User{
			Id:           uuid.New(),
			Name:         fmt.Sprintf("%s %s", fu.FirstName, fu.LastName),
			Email:        fu.Email,
			PasswordHash: string(hashedPassword),
			DepartmentId: departments[deptIdx].Id,
			IsApproved:   true,
			ApprovedAt:   func() *time.Time { now := time.Now(); return &now }(),
		}
		if err := db.Create(&user).Error; err != nil {
			return err
		}
	}

	return nil
}
