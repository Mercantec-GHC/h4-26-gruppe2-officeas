package seed

import (
	"testing"

	"stuff/models"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupSeedTestDB(t *testing.T) *gorm.DB {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test db: %v", err)
	}
	if err := db.AutoMigrate(&models.Department{}, &models.User{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

var expectedDepartmentNames = []string{
	"IT-Support",
	"HR",
	"Salg",
	"Udvikling",
	"Kundeservice",
	"Produkt",
	"Økonomi",
	"Drift",
	"Marketing",
	"Ledelse",
	"Design",
	"Datateam",
}

func TestSeedDepartments(t *testing.T) {
	db := setupSeedTestDB(t)

	t.Run("creates all expected departments", func(t *testing.T) {
		if err := SeedDepartments(db); err != nil {
			t.Fatalf("SeedDepartments: %v", err)
		}

		var count int64

		if err := db.Model(&models.Department{}).Count(&count).Error; err != nil {
			t.Fatalf("count departments: %v", err)
		}
		
		if count != int64(len(expectedDepartmentNames)) {
			t.Errorf("department count = %d, want %d", count, len(expectedDepartmentNames))
		}

		for _, name := range expectedDepartmentNames {
			var d models.Department
		
			if err := db.Where("name = ?", name).First(&d).Error; err != nil {
				t.Errorf("department %q not found: %v", name, err)
			}
		}
	})

	t.Run("idempotent: second run does not duplicate", func(t *testing.T) {
		if err := SeedDepartments(db); err != nil {
			t.Fatalf("SeedDepartments second run: %v", err)
		}

		var count int64
		
		if err := db.Model(&models.Department{}).Count(&count).Error; err != nil {
			t.Fatalf("count departments: %v", err)
		}
		
		if count != int64(len(expectedDepartmentNames)) {
			t.Errorf("after second run: department count = %d, want %d", count, len(expectedDepartmentNames))
		}
	})
}

func TestSeedUsers(t *testing.T) {
	db := setupSeedTestDB(t)

	if err := SeedDepartments(db); err != nil {
		t.Fatalf("SeedDepartments: %v", err)
	}

	t.Run("creates Mercantec Test user with IT-Support department", func(t *testing.T) {
		if err := SeedUsers(db); err != nil {
			t.Fatalf("SeedUsers: %v", err)
		}

		var u models.User
		
		if err := db.Where("email = ?", mercantecTestEmail).First(&u).Error; err != nil {
			t.Fatalf("Mercantec user not found: %v", err)
		}
		
		if u.Name != "Mercantec Test" {
			t.Errorf("user name = %q, want Mercantec Test", u.Name)
		}
		
		if u.Email != mercantecTestEmail {
			t.Errorf("user email = %q, want %q", u.Email, mercantecTestEmail)
		}
		
		if u.PasswordHash == "" {
			t.Error("expected password hash to be set")
		}
		
		if !u.IsApproved {
			t.Error("expected Mercantec user to be approved")
		}

		var dept models.Department
		
		if err := db.Where("id = ?", u.DepartmentId).First(&dept).Error; err != nil {
			t.Fatalf("department not found: %v", err)
		}
		
		if dept.Name != "IT-Support" {
			t.Errorf("department name = %q, want IT-Support", dept.Name)
		}
	})

	t.Run("idempotent: second run does not duplicate Mercantec user", func(t *testing.T) {
		if err := SeedUsers(db); err != nil {
			t.Fatalf("SeedUsers second run: %v", err)
		}

		var count int64
		
		if err := db.Model(&models.User{}).Where("email = ?", mercantecTestEmail).Count(&count).Error; err != nil {
			t.Fatalf("count Mercantec users: %v", err)
		}
		
		if count != 1 {
			t.Errorf("Mercantec user count = %d, want 1 (idempotent)", count)
		}
	})
}
