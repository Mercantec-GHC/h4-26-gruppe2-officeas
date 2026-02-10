package handlers

import (
	"github.com/golang-jwt/jwt/v5"
)

// parseAndValidateJWT parses and validates a raw JWT string.
// Used by the WebSocket handler where the token comes from a query param
// instead of the Authorization header.
func parseAndValidateJWT(tokenStr string) (*jwt.Token, error) {
	return jwt.ParseWithClaims(tokenStr, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return getJWTSecret(), nil
	})
}
