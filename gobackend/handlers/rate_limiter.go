package handlers

import (
	"net/http"
	"sync"
	"time"
)

// RateLimiter implements a simple rate limiting mechanism
type RateLimiter struct {
	requests map[string][]time.Time
	mu       sync.Mutex
	limit    int
	window   time.Duration
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		requests: make(map[string][]time.Time),
		limit:    limit,
		window:   window,
	}
}

// RateLimitMiddleware limits requests per IP address
func (rl *RateLimiter) RateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := getClientIP(r)
		
		rl.mu.Lock()
		defer rl.mu.Unlock()

		now := time.Now()
		
		// Initialize if first request from this IP
		if _, exists := rl.requests[ip]; !exists {
			rl.requests[ip] = []time.Time{}
		}

		// Remove old requests outside the time window
		validRequests := []time.Time{}
		for _, reqTime := range rl.requests[ip] {
			if now.Sub(reqTime) < rl.window {
				validRequests = append(validRequests, reqTime)
			}
		}
		
		// Check if limit exceeded
		if len(validRequests) >= rl.limit {
			w.Header().Set("Retry-After", "60")
			http.Error(w, "Rate limit exceeded. Please try again later.", http.StatusTooManyRequests)
			return
		}

		// Add current request
		validRequests = append(validRequests, now)
		rl.requests[ip] = validRequests

		next.ServeHTTP(w, r)
	})
}

// getClientIP extracts the client IP from the request
func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header first (for proxied requests)
	forwarded := r.Header.Get("X-Forwarded-For")
	if forwarded != "" {
		return forwarded
	}

	// Check X-Real-IP header
	realIP := r.Header.Get("X-Real-IP")
	if realIP != "" {
		return realIP
	}

	// Fall back to RemoteAddr
	return r.RemoteAddr
}

// Cleanup removes old entries periodically
func (rl *RateLimiter) Cleanup() {
	ticker := time.NewTicker(1 * time.Hour)
	go func() {
		for range ticker.C {
			rl.mu.Lock()
			now := time.Now()
			for ip, requests := range rl.requests {
				validRequests := []time.Time{}
				for _, reqTime := range requests {
					if now.Sub(reqTime) < rl.window {
						validRequests = append(validRequests, reqTime)
					}
				}
				if len(validRequests) == 0 {
					delete(rl.requests, ip)
				} else {
					rl.requests[ip] = validRequests
				}
			}
			rl.mu.Unlock()
		}
	}()
}
