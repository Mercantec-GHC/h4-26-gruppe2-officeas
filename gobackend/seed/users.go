package seed

import (
	"stuff/models"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// SeedPassword is the password for all seeded users (development only).
// Documented here so devs can log in: Seeder123!
const SeedPassword = "Seeder123!"

// SeedUserEmails are the emails used for seed users (for other seeders to look up).
var SeedUserEmails = []string{
	"alice@seed.example.com",
	"bob@seed.example.com",
	"carol@seed.example.com",
	"dave@seed.example.com",
}

// SeedUsers creates seed users if they do not exist.
// Idempotent: skips creation when a user with the same email exists.
// All seed users use password Seeder123!
func SeedUsers(db *gorm.DB) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(SeedPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	var deptIT, deptHR, deptSales models.Department
	if err := db.Where("name = ?", "IT").First(&deptIT).Error; err != nil {
		return err
	}
	
	if err := db.Where("name = ?", "HR").First(&deptHR).Error; err != nil {
		return err
	}

	if err := db.Where("name = ?", "Sales").First(&deptSales).Error; err != nil {
		return err
	}

	users := []struct {
		name   string
		email  string
		deptID uuid.UUID
	}{
		{"Alice Admin", "alice@seed.example.com", deptIT.Id},
		{"Bob Developer", "bob@seed.example.com", deptIT.Id},
		{"Carol Manager", "carol@seed.example.com", deptHR.Id},
		{"Dave Sales", "dave@seed.example.com", deptSales.Id},
	}

	for _, u := range users {
		var existing models.User

		if err := db.Where("email = ?", u.email).First(&existing).Error; err == nil {
			continue
		}

		user := models.User{
			Id:           uuid.New(),
			Name:         u.name,
			Email:        u.email,
			PasswordHash: string(hashedPassword),
			DepartmentId: u.deptID,
		}
		
		if err := db.Create(&user).Error; err != nil {
			return err
		}
	}

	return nil
}
