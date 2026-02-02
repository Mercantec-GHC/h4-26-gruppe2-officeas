package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"time"

	"stuff/models"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// Auth holds DB for authentication handlers
type Auth struct {
	DB *gorm.DB
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Token string      `json:"token"`
	User  models.User `json:"user"`
}

type RegisterRequest struct {
	Name         string    `json:"name"`
	Email        string    `json:"email"`
	Password     string    `json:"password"`
	DepartmentId uuid.UUID `json:"department_id"`
}

type SSORequest struct {
	Provider     string `json:"provider"` // "google" or "github"
	IDToken      string `json:"id_token"`
	Email        string `json:"email"`
	Name         string `json:"name"`
	DepartmentId uuid.UUID `json:"department_id,omitempty"`
}

type Claims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	jwt.RegisteredClaims
}

// getJWTSecret retrieves the JWT secret from environment or uses a default (not recommended for production)
func getJWTSecret() []byte {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "your-secret-key-change-this-in-production"
	}
	return []byte(secret)
}

// Login godoc
// @Summary      User login
// @Description  Authenticate user and return JWT token
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        credentials  body      LoginRequest  true  "Login credentials"
// @Success      200  {object}  LoginResponse
// @Failure      400  {string}  string  "Invalid request"
// @Failure      401  {string}  string  "Invalid credentials"
// @Router       /auth/login [post]
func (h Auth) Login(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Sanitize and validate input
	req.Email = SanitizeInput(req.Email)
	if !ValidateEmail(req.Email) {
		http.Error(w, "Invalid email format", http.StatusBadRequest)
		return
	}

	var user models.User
	if err := h.DB.Preload("Department").First(&user, "email = ?", req.Email).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			http.Error(w, "Invalid credentials", http.StatusUnauthorized)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		return
	}

	// Generate JWT token
	token, err := h.generateToken(user.Id.String(), user.Email)
	if err != nil {
		http.Error(w, "Failed to generate token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(LoginResponse{
		Token: token,
		User:  user,
	})
}

// Register godoc
// @Summary      User registration
// @Description  Register a new user
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        user  body      RegisterRequest  true  "Registration details"
// @Success      201  {object}  LoginResponse
// @Failure      400  {string}  string  "Invalid request"
// @Router       /auth/register [post]
func (h Auth) Register(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Sanitize input
	req.Name = SanitizeInput(req.Name)
	req.Email = SanitizeInput(req.Email)

	// Validate name
	if !ValidateName(req.Name) {
		http.Error(w, "Invalid name. Name must be 2-100 characters and contain only letters, spaces, hyphens, or apostrophes", http.StatusBadRequest)
		return
	}

	// Validate email
	if !ValidateEmail(req.Email) {
		http.Error(w, "Invalid email format", http.StatusBadRequest)
		return
	}

	// Validate password
	if valid, msg := ValidatePassword(req.Password); !valid {
		http.Error(w, msg, http.StatusBadRequest)
		return
	}

	// Check if user already exists
	var existingUser models.User
	if err := h.DB.First(&existingUser, "email = ?", req.Email).Error; err == nil {
		http.Error(w, "User already exists", http.StatusBadRequest)
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "Failed to hash password", http.StatusInternalServerError)
		return
	}

	// Create user
	user := models.User{
		Id:           uuid.New(),
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: string(hashedPassword),
		DepartmentId: req.DepartmentId,
	}

	if err := h.DB.Create(&user).Error; err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Load department relation
	h.DB.Preload("Department").First(&user, "id = ?", user.Id)

	// Generate JWT token
	token, err := h.generateToken(user.Id.String(), user.Email)
	if err != nil {
		http.Error(w, "Failed to generate token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(LoginResponse{
		Token: token,
		User:  user,
	})
}

// SSOLogin godoc
// @Summary      SSO login (Google/GitHub)
// @Description  Authenticate user via SSO and return JWT token
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        sso  body      SSORequest  true  "SSO credentials"
// @Success      200  {object}  LoginResponse
// @Failure      400  {string}  string  "Invalid request"
// @Router       /auth/sso [post]
func (h Auth) SSOLogin(w http.ResponseWriter, r *http.Request) {
	var req SSORequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Sanitize input
	req.Email = SanitizeInput(req.Email)
	req.Name = SanitizeInput(req.Name)

	// Verify Google token if it's a Google SSO request
	if req.Provider == "google" {
		tokenInfo, err := VerifyGoogleToken(req.IDToken)
		if err != nil {
			http.Error(w, "Invalid Google token: "+err.Error(), http.StatusUnauthorized)
			return
		}
		
		// Use verified email and name from Google
		req.Email = tokenInfo.Email
		if tokenInfo.Name != "" {
			req.Name = tokenInfo.Name
		}
	}

	// Validate email
	if !ValidateEmail(req.Email) {
		http.Error(w, "Invalid email format", http.StatusBadRequest)
		return
	}

	// Try to find existing user
	var user models.User
	err := h.DB.Preload("Department").First(&user, "email = ?", req.Email).Error
	
	if err == gorm.ErrRecordNotFound {
		// Create new user for SSO
		// Use a default department if not provided
		departmentId := req.DepartmentId
		if departmentId == uuid.Nil {
			// Get first department as default
			var dept models.Department
			if err := h.DB.First(&dept).Error; err != nil {
				http.Error(w, "No default department found", http.StatusInternalServerError)
				return
			}
			departmentId = dept.Id
		}

		user = models.User{
			Id:           uuid.New(),
			Name:         req.Name,
			Email:        req.Email,
			PasswordHash: "", // No password for SSO users
			DepartmentId: departmentId,
		}

		if err := h.DB.Create(&user).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		h.DB.Preload("Department").First(&user, "id = ?", user.Id)
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Generate JWT token
	token, err := h.generateToken(user.Id.String(), user.Email)
	if err != nil {
		http.Error(w, "Failed to generate token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(LoginResponse{
		Token: token,
		User:  user,
	})
}

// generateToken creates a JWT token for the user
func (h Auth) generateToken(userID, email string) (string, error) {
	claims := Claims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(getJWTSecret())
}

// RegisterAuth registers authentication routes
func RegisterAuth(router *mux.Router, h Auth, basePath string) {
	router.HandleFunc(basePath+"/login", h.Login).Methods("POST")
	router.HandleFunc(basePath+"/register", h.Register).Methods("POST")
	router.HandleFunc(basePath+"/sso", h.SSOLogin).Methods("POST")
	router.HandleFunc(basePath+"/github/callback", h.GitHubCallback).Methods("GET")
}

// GitHubCallback godoc
// @Summary      GitHub OAuth callback
// @Description  Handle GitHub OAuth callback and exchange code for token
// @Tags         auth
// @Produce      json
// @Param        code   query     string  true  "Authorization code"
// @Success      200  {object}  LoginResponse
// @Failure      400  {string}  string  "Invalid request"
// @Router       /auth/github/callback [get]
func (h Auth) GitHubCallback(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	if code == "" {
		http.Error(w, "No authorization code provided", http.StatusBadRequest)
		return
	}

	// Exchange code for access token
	clientID := os.Getenv("GITHUB_CLIENT_ID")
	clientSecret := os.Getenv("GITHUB_CLIENT_SECRET")

	if clientID == "" || clientSecret == "" {
		http.Error(w, "GitHub OAuth not configured", http.StatusInternalServerError)
		return
	}

	// Create form data for token exchange
	tokenURL := "https://github.com/login/oauth/access_token"
	data := map[string]string{
		"client_id":     clientID,
		"client_secret": clientSecret,
		"code":          code,
	}

	jsonData, _ := json.Marshal(data)
	req, err := http.NewRequest("POST", tokenURL, bytes.NewBuffer(jsonData))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to exchange code", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var tokenResponse struct {
		AccessToken string `json:"access_token"`
		TokenType   string `json:"token_type"`
		Scope       string `json:"scope"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenResponse); err != nil {
		http.Error(w, "Failed to parse token response", http.StatusInternalServerError)
		return
	}

	// Get user info from GitHub
	userReq, err := http.NewRequest("GET", "https://api.github.com/user", nil)
	if err != nil {
		http.Error(w, "Failed to create user request", http.StatusInternalServerError)
		return
	}

	userReq.Header.Set("Authorization", "Bearer "+tokenResponse.AccessToken)
	userReq.Header.Set("Accept", "application/json")

	userResp, err := client.Do(userReq)
	if err != nil {
		http.Error(w, "Failed to get user info", http.StatusInternalServerError)
		return
	}
	defer userResp.Body.Close()

	var githubUser struct {
		Login string `json:"login"`
		Name  string `json:"name"`
		Email string `json:"email"`
	}

	if err := json.NewDecoder(userResp.Body).Decode(&githubUser); err != nil {
		http.Error(w, "Failed to parse user info", http.StatusInternalServerError)
		return
	}

	// If email is not public, fetch it separately
	if githubUser.Email == "" {
		emailReq, _ := http.NewRequest("GET", "https://api.github.com/user/emails", nil)
		emailReq.Header.Set("Authorization", "Bearer "+tokenResponse.AccessToken)
		emailReq.Header.Set("Accept", "application/json")

		emailResp, err := client.Do(emailReq)
		if err == nil {
			defer emailResp.Body.Close()
			var emails []struct {
				Email   string `json:"email"`
				Primary bool   `json:"primary"`
			}
			if err := json.NewDecoder(emailResp.Body).Decode(&emails); err == nil {
				for _, e := range emails {
					if e.Primary {
						githubUser.Email = e.Email
						break
					}
				}
			}
		}
	}

	// Try to find or create user
	var user models.User
	err = h.DB.Preload("Department").First(&user, "email = ?", githubUser.Email).Error

	if err == gorm.ErrRecordNotFound {
		// Get first department as default
		var dept models.Department
		if err := h.DB.First(&dept).Error; err != nil {
			http.Error(w, "No default department found", http.StatusInternalServerError)
			return
		}

		userName := githubUser.Name
		if userName == "" {
			userName = githubUser.Login
		}

		user = models.User{
			Id:           uuid.New(),
			Name:         userName,
			Email:        githubUser.Email,
			PasswordHash: "", // No password for SSO users
			DepartmentId: dept.Id,
		}

		if err := h.DB.Create(&user).Error; err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		h.DB.Preload("Department").First(&user, "id = ?", user.Id)
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Generate JWT token
	token, err := h.generateToken(user.Id.String(), user.Email)
	if err != nil {
		http.Error(w, "Failed to generate token", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(LoginResponse{
		Token: token,
		User:  user,
	})
}

