package security

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
)

// Encryptor handles AES-256-GCM encryption/decryption for message content.
// The key is provided once at startup; the cipher.AEAD is reused (goroutine-safe).
// Each Encrypt call generates a fresh 12-byte nonce, prepended to the ciphertext
// before base64-encoding so Decrypt can extract it.
type Encryptor struct {
	key    []byte
	aesGCM cipher.AEAD
}

// NewEncryptor creates an Encryptor from a raw 32-byte key.
func NewEncryptor(key []byte) (*Encryptor, error) {
	if len(key) != 32 {
		return nil, errors.New("encryption key must be exactly 32 bytes (AES-256)")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("encryption: create cipher: %w", err)
	}
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("encryption: create GCM: %w", err)
	}
	return &Encryptor{key: key, aesGCM: aesGCM}, nil
}

// NewEncryptorFromBase64 creates an Encryptor from a base64-encoded key (e.g. from env vars).
func NewEncryptorFromBase64(encoded string) (*Encryptor, error) {
	if encoded == "" {
		return nil, errors.New("MESSAGE_ENCRYPTION_KEY environment variable is not set")
	}
	key, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, fmt.Errorf("MESSAGE_ENCRYPTION_KEY is not valid base64: %w", err)
	}
	return NewEncryptor(key)
}

// Encrypt encrypts plaintext with AES-256-GCM.
// Output (base64): nonce (12 bytes) || ciphertext+tag.
// A fresh nonce is generated each call.
func (e *Encryptor) Encrypt(plaintext string) (string, error) {
	// Generate a random nonce for this message
	nonce := make([]byte, e.aesGCM.NonceSize()) // 12 bytes for GCM
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("encryption: generate nonce: %w", err)
	}

	// Seal appends ciphertext+tag to the nonce prefix
	ciphertext := e.aesGCM.Seal(nonce, nonce, []byte(plaintext), nil)

	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decodes the base64 blob, extracts the nonce prefix,
// and decrypts the remaining ciphertext with AES-256-GCM.
func (e *Encryptor) Decrypt(encoded string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", fmt.Errorf("decryption: base64 decode: %w", err)
	}

	nonceSize := e.aesGCM.NonceSize()
	if len(data) < nonceSize {
		return "", errors.New("decryption: ciphertext too short")
	}

	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := e.aesGCM.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", fmt.Errorf("decryption: open: %w", err)
	}

	return string(plaintext), nil
}
