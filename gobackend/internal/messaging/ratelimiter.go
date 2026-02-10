package messaging

import (
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
	"golang.org/x/time/rate"
)

// ErrRateLimited is returned when a user exceeds the messaging rate limit.
var ErrRateLimited = errors.New("message rate limit exceeded, please slow down")

// MessageRateLimiter enforces per-user send rate limits with a token bucket.
// The map is mutex-protected; individual rate.Limiters are goroutine-safe.
type MessageRateLimiter struct {
	mu       sync.Mutex
	limiters map[uuid.UUID]*limiterEntry
	rate     rate.Limit // tokens per second
	burst    int        // max burst size
}

type limiterEntry struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// NewMessageRateLimiter creates a limiter: r messages/sec, with burst.
// e.g. NewMessageRateLimiter(2, 10) = 2 msg/s sustained, burst of 10.
func NewMessageRateLimiter(r rate.Limit, burst int) *MessageRateLimiter {
	mrl := &MessageRateLimiter{
		limiters: make(map[uuid.UUID]*limiterEntry),
		rate:     r,
		burst:    burst,
	}
	go mrl.cleanupLoop()
	return mrl
}

// Allow checks whether the user is allowed to send a message right now.
// Returns nil if allowed, ErrRateLimited otherwise.
func (mrl *MessageRateLimiter) Allow(userID uuid.UUID) error {
	mrl.mu.Lock()
	entry, exists := mrl.limiters[userID]
	if !exists {
		entry = &limiterEntry{
			limiter:  rate.NewLimiter(mrl.rate, mrl.burst),
			lastSeen: time.Now(),
		}
		mrl.limiters[userID] = entry
	} else {
		entry.lastSeen = time.Now()
	}
	mrl.mu.Unlock()

	// Allow() is goroutine-safe on the individual limiter.
	if !entry.limiter.Allow() {
		return ErrRateLimited
	}
	return nil
}

// cleanupLoop removes stale limiters (inactive >10 min) to avoid leaking memory.
func (mrl *MessageRateLimiter) cleanupLoop() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		mrl.mu.Lock()
		cutoff := time.Now().Add(-10 * time.Minute)
		for uid, entry := range mrl.limiters {
			if entry.lastSeen.Before(cutoff) {
				delete(mrl.limiters, uid)
			}
		}
		mrl.mu.Unlock()
	}
}
