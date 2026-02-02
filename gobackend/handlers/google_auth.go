package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// GoogleTokenInfo represents the response from Google token verification
type GoogleTokenInfo struct {
	Email         string `json:"email"`
	EmailVerified string `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
	Locale        string `json:"locale"`
}

// VerifyGoogleToken verifies a Google ID token
func VerifyGoogleToken(idToken string) (*GoogleTokenInfo, error) {
	// Google's token verification endpoint
	url := fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?id_token=%s", idToken)

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to verify token: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("invalid token: status code %d", resp.StatusCode)
	}

	var tokenInfo GoogleTokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&tokenInfo); err != nil {
		return nil, fmt.Errorf("failed to decode token info: %v", err)
	}

	// Verify email is verified
	if tokenInfo.EmailVerified != "true" {
		return nil, fmt.Errorf("email not verified")
	}

	return &tokenInfo, nil
}
