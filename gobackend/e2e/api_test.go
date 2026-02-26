// Package e2e runs end-to-end tests against a real running backend.
// Start the backend (and DB) first, e.g. make up && make seed, or make backend-run with .env,
// then run: go test ./e2e -v
// Base URL defaults to http://localhost:8080/api; override with E2E_BASE_URL.
package e2e

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"testing"
	"time"

	"stuff/seed"
)

const (
	// Default matches nginx (make up): port 8080, API under /api. For backend-only (make backend-run) use E2E_BASE_URL=http://localhost:8080.
	defaultBaseURL   = "http://localhost:8080/api"
	seedUserEmail    = "mercantec@mercantec.dk"
	seedUserPassword = "Password123!"
)

func baseURL() string {
	if u := os.Getenv("E2E_BASE_URL"); u != "" {
		return u
	}

	return defaultBaseURL
}

// loginToken performs POST /auth/login and returns the JWT token. Fails the test on error.
func loginToken(t *testing.T, client *http.Client, base string) string {
	t.Helper()
	
	loginBody, _ := json.Marshal(map[string]string{
		"email":    seedUserEmail,
		"password": seedUserPassword,
	})

	resp, err := client.Post(base+"/auth/login", "application/json", bytes.NewReader(loginBody))

	if err != nil {
		t.Fatalf("login request failed (is the backend running and seeded?): %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /auth/login: status %d, want 200 (run make seed to create %s)", resp.StatusCode, seedUserEmail)
	}

	var loginResp struct {
		Token string `json:"token"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil || loginResp.Token == "" {
		t.Fatalf("login response missing token: %v", err)
	}
	
	return loginResp.Token
}

// loginTokenAs performs POST /auth/login with the given credentials and returns the JWT token.
func loginTokenAs(t *testing.T, client *http.Client, base, email, password string) string {
	t.Helper()
	loginBody, _ := json.Marshal(map[string]string{"email": email, "password": password})
	resp, err := client.Post(base+"/auth/login", "application/json", bytes.NewReader(loginBody))

	if err != nil {
		t.Fatalf("login request failed: %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /auth/login: status %d, want 200", resp.StatusCode)
	}
	
	var loginResp struct {
		Token string `json:"token"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil || loginResp.Token == "" {
		t.Fatalf("login response missing token: %v", err)
	}
	
	return loginResp.Token
}

// loginTokenAndUserID performs POST /auth/login with the default seed user and returns the JWT token and user ID.
func loginTokenAndUserID(t *testing.T, client *http.Client, base string) (token, userID string) {
	t.Helper()
	loginBody, _ := json.Marshal(map[string]string{"email": seedUserEmail, "password": seedUserPassword})
	resp, err := client.Post(base+"/auth/login", "application/json", bytes.NewReader(loginBody))
	if err != nil {
		t.Fatalf("login request failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /auth/login: status %d, want 200", resp.StatusCode)
	}
	var loginResp struct {
		Token string `json:"token"`
		User  struct {
			Id string `json:"id"`
		} `json:"user"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil || loginResp.Token == "" || loginResp.User.Id == "" {
		t.Fatalf("login response missing token or user.id: %v", err)
	}
	return loginResp.Token, loginResp.User.Id
}

func TestLoginAndDepartments(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token := loginToken(t, client, base)

	req, _ := http.NewRequest(http.MethodGet, base+"/departments", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	
	if err != nil {
		t.Fatalf("GET /departments: %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Errorf("GET /departments with token: status %d, want 200", resp.StatusCode)
	}
}

func TestLoginAndUsers(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token := loginToken(t, client, base)

	req, _ := http.NewRequest(http.MethodGet, base+"/users", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	
	if err != nil {
		t.Fatalf("GET /users: %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Errorf("GET /users with token: status %d, want 200", resp.StatusCode)
	}
}

func TestLoginAndTicketsList(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token := loginToken(t, client, base)

	req, _ := http.NewRequest(http.MethodGet, base+"/tickets", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	
	if err != nil {
		t.Fatalf("GET /tickets: %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Errorf("GET /tickets with token: status %d, want 200", resp.StatusCode)
	}
}

func TestLoginAndShifts(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token := loginToken(t, client, base)

	req, _ := http.NewRequest(http.MethodGet, base+"/shifts", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	
	if err != nil {
		t.Fatalf("GET /shifts: %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Errorf("GET /shifts with token: status %d, want 200", resp.StatusCode)
	}
}

func TestLoginAndNotifications(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token := loginToken(t, client, base)

	req, _ := http.NewRequest(http.MethodGet, base+"/notifications", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	
	if err != nil {
		t.Fatalf("GET /notifications: %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Errorf("GET /notifications with token: status %d, want 200", resp.StatusCode)
	}
}

func TestLoginAndAbsenceRequestsList(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token := loginTokenAs(t, client, base, seed.E2EManagerEmail, seed.E2EManagerPassword)

	req, _ := http.NewRequest(http.MethodGet, base+"/absence-requests", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	
	if err != nil {
		t.Fatalf("GET /absence-requests: %v", err)
	}
	
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		t.Errorf("GET /absence-requests with token: status %d, want 200", resp.StatusCode)
	}
}

// TestLoginAndTicketAndComment runs against the real DB: create a ticket, add a comment, update the ticket, then delete (cleanup).
func TestLoginAndTicketAndCommentCRUD(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token, userID := loginTokenAndUserID(t, client, base)

	// 1. Create ticket
	createBody, _ := json.Marshal(map[string]string{
		"title":       "E-E ticket",
		"description": "E2e test ticket",
	})

	req, _ := http.NewRequest(http.MethodPost, base+"/tickets", bytes.NewReader(createBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	
	if err != nil {
		t.Fatalf("POST /tickets: %v", err)
	}
	
	if resp.StatusCode != http.StatusCreated {
		resp.Body.Close()
		t.Fatalf("POST /tickets: status %d, want 201", resp.StatusCode)
	}
	
	var created struct {
		Id string `json:"id"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&created); err != nil || created.Id == "" {
		resp.Body.Close()
		t.Fatalf("decode created ticket: %v or missing id", err)
	}
	
	resp.Body.Close()
	ticketID := created.Id

	// 2. Add comment on ticket
	commentBody, _ := json.Marshal(map[string]string{
		"user_id": userID,
		"content": "E-E comment on ticket",
	})
	
	req, _ = http.NewRequest(http.MethodPost, base+"/tickets/"+ticketID+"/comments", bytes.NewReader(commentBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err = client.Do(req)
	
	if err != nil {
		t.Fatalf("POST /tickets/.../comments: %v", err)
	}
	
	if resp.StatusCode != http.StatusCreated {
		resp.Body.Close()
		t.Fatalf("POST /tickets/.../comments: status %d, want 201", resp.StatusCode)
	}
	
	resp.Body.Close()

	// 3. Update ticket
	updateBody, _ := json.Marshal(map[string]string{
		"title":       "E-E ticket updated",
		"description": "E2e test ticket updated",
	})
	
	req, _ = http.NewRequest(http.MethodPut, base+"/tickets/"+ticketID, bytes.NewReader(updateBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err = client.Do(req)
	
	if err != nil {
		t.Fatalf("PUT /tickets: %v", err)
	}
	
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		t.Fatalf("PUT /tickets: status %d, want 200", resp.StatusCode)
	}
	
	resp.Body.Close()

	// 4. Delete ticket (cleanup)
	req, _ = http.NewRequest(http.MethodDelete, base+"/tickets/"+ticketID, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = client.Do(req)
	
	if err != nil {
		t.Fatalf("DELETE /tickets: %v", err)
	}
	
	resp.Body.Close()
	
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("DELETE /tickets: status %d, want 204", resp.StatusCode)
	}
}

// TestLoginAndUserCRUD runs against the real DB: login as Ledelse manager, create a user, update them, then delete (cleanup).
func TestLoginAndUserCRUD(t *testing.T) {
	base := baseURL()
	client := &http.Client{Timeout: 10 * time.Second}
	token := loginTokenAs(t, client, base, seed.E2EManagerEmail, seed.E2EManagerPassword)

	// 1. Get a department ID for the new user
	req, _ := http.NewRequest(http.MethodGet, base+"/departments", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)

	if err != nil {
		t.Fatalf("GET /departments: %v", err)
	}
	
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		t.Fatalf("GET /departments: status %d, want 200", resp.StatusCode)
	}
	
	var depts []struct {
		Id   string `json:"id"`
		Name string `json:"name"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&depts); err != nil || len(depts) == 0 {
		resp.Body.Close()
		t.Fatalf("decode departments: %v or empty", err)
	}
	
	resp.Body.Close()
	departmentID := depts[0].Id

	// 2. Create user
	createBody, _ := json.Marshal(map[string]string{
		"name":          "E-E Test User",
		"email":         "e2e-created@test.com",
		"password":      "Password123!",
		"department_id": departmentID,
	})
	
	req, _ = http.NewRequest(http.MethodPost, base+"/users", bytes.NewReader(createBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err = client.Do(req)
	
	if err != nil {
		t.Fatalf("POST /users: %v", err)
	}
	
	if resp.StatusCode != http.StatusCreated {
		resp.Body.Close()
		t.Fatalf("POST /users: status %d, want 201", resp.StatusCode)
	}
	
	var created struct {
		Id string `json:"id"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&created); err != nil || created.Id == "" {
		resp.Body.Close()
		t.Fatalf("decode created user: %v or missing id", err)
	}
	
	resp.Body.Close()
	userID := created.Id

	// 3. Update user
	updateBody, _ := json.Marshal(map[string]string{
		"name": "E-E Test User Updated",
	})
	
	req, _ = http.NewRequest(http.MethodPut, base+"/users/"+userID, bytes.NewReader(updateBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	resp, err = client.Do(req)
	
	if err != nil {
		t.Fatalf("PUT /users: %v", err)
	}
	
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		t.Fatalf("PUT /users: status %d, want 200", resp.StatusCode)
	}
	
	resp.Body.Close()

	// 4. Delete user (cleanup)
	req, _ = http.NewRequest(http.MethodDelete, base+"/users/"+userID, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err = client.Do(req)

	if err != nil {
		t.Fatalf("DELETE /users: %v", err)
	}
	
	resp.Body.Close()
	
	if resp.StatusCode != http.StatusNoContent {
		t.Errorf("DELETE /users: status %d, want 204", resp.StatusCode)
	}
}

