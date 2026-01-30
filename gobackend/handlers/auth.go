package handlers

import (
    "encoding/json"
    "net/http"
    "os"
    "time"

    "github.com/golang-jwt/jwt/v5"
    "golang.org/x/crypto/bcrypt"
    "gorm.io/gorm"

    "stuff/models"
)

// Auth holds DB for auth handlers
type Auth struct {
    DB *gorm.DB
}

type loginRequest struct {
    Email    string `json:"email"`
    Password string `json:"password"`
}

type loginResponse struct {
    Token string `json:"token"`
}

// Login authenticates a user and returns a JWT
func (h Auth) Login(w http.ResponseWriter, r *http.Request) {
    var req loginRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }

    var u models.User
    if err := h.DB.First(&u, "email = ?", req.Email).Error; err != nil {
        http.Error(w, "invalid credentials", http.StatusUnauthorized)
        return
    }

    if err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)); err != nil {
        http.Error(w, "invalid credentials", http.StatusUnauthorized)
        return
    }

    secret := os.Getenv("JWT_SECRET")
    if secret == "" {
        secret = "dev-secret"
    }

    claims := jwt.MapClaims{
        "sub":   u.Id.String(),
        "email": u.Email,
        "exp":   time.Now().Add(24 * time.Hour).Unix(),
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    ts, err := token.SignedString([]byte(secret))
    if err != nil {
        http.Error(w, "failed to create token", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(loginResponse{Token: ts})
}

// JWTAuthMiddleware protects endpoints by validating Bearer token
func JWTAuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        auth := r.Header.Get("Authorization")
        if auth == "" {
            http.Error(w, "missing authorization header", http.StatusUnauthorized)
            return
        }

        // Expect: Bearer <token>
        const prefix = "Bearer "
        if len(auth) <= len(prefix) || auth[:len(prefix)] != prefix {
            http.Error(w, "invalid authorization header", http.StatusUnauthorized)
            return
        }

        tokenStr := auth[len(prefix):]

        secret := os.Getenv("JWT_SECRET")
        if secret == "" {
            secret = "dev-secret"
        }

        token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
            if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, jwt.ErrTokenUnverifiable
            }
            return []byte(secret), nil
        })

        if err != nil || !token.Valid {
            http.Error(w, "invalid token", http.StatusUnauthorized)
            return
        }

        next.ServeHTTP(w, r)
    })
}
