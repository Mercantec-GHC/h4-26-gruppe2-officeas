package handlers

import (
	"net/mail"
	"regexp"
	"strings"
	"unicode"
)

// ValidateEmail checks if email is valid
func ValidateEmail(email string) bool {
	email = strings.TrimSpace(email)
	if email == "" {
		return false
	}
	_, err := mail.ParseAddress(email)
	return err == nil
}

// ValidatePassword checks password strength
// Requirements:
// - At least 8 characters
// - At least one uppercase letter
// - At least one lowercase letter
// - At least one number
func ValidatePassword(password string) (bool, string) {
	if len(password) < 8 {
		return false, "Password must be at least 8 characters long"
	}

	var (
		hasUpper  = false
		hasLower  = false
		hasNumber = false
	)

	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsNumber(char):
			hasNumber = true
		}
	}

	if !hasUpper {
		return false, "Password must contain at least one uppercase letter"
	}
	if !hasLower {
		return false, "Password must contain at least one lowercase letter"
	}
	if !hasNumber {
		return false, "Password must contain at least one number"
	}

	return true, ""
}

// ValidateName checks if name is valid
func ValidateName(name string) bool {
	name = strings.TrimSpace(name)
	if len(name) < 2 || len(name) > 100 {
		return false
	}
	
	// Allow letters, spaces, hyphens, and apostrophes
	validNamePattern := regexp.MustCompile(`^[a-zA-ZæøåÆØÅ\s\-']+$`)
	return validNamePattern.MatchString(name)
}

// SanitizeInput removes potentially dangerous characters
func SanitizeInput(input string) string {
	input = strings.TrimSpace(input)
	// Remove null bytes
	input = strings.ReplaceAll(input, "\x00", "")
	return input
}
