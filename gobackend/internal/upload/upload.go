package upload

import (
	"errors"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// Sentinel errors for handlers to check with errors.Is.
var (
	ErrTooLarge    = errors.New("upload: file too large")
	ErrInvalidType = errors.New("upload: invalid content type")
	ErrPathEscape  = errors.New("upload: path escapes upload directory")
)

const (
	// MaxUploadSize is the maximum allowed image size (10 MB).
	MaxUploadSize = 10 << 20

	// FormFieldImage is the multipart form field name for the image file.
	FormFieldImage = "image"
)

// AllowedImageTypes defines allowed MIME types for uploads.
var AllowedImageTypes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/webp": true,
}

// contentTypeFromFilename returns an allowed image MIME type from a filename extension.
func contentTypeFromFilename(name string) string {
	lower := strings.ToLower(name)
	switch {
	case strings.HasSuffix(lower, ".png"):
		return "image/png"
	case strings.HasSuffix(lower, ".webp"):
		return "image/webp"
	case strings.HasSuffix(lower, ".jpg"), strings.HasSuffix(lower, ".jpeg"):
		return "image/jpeg"
	default:
		return "image/jpeg"
	}
}

// ExtensionByContentType returns a file extension for the given content type.
func ExtensionByContentType(ct string) string {
	ct = strings.TrimSpace(strings.Split(ct, ";")[0])
	
	switch ct {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	default:
		return ".jpg"
	}
}

// ParseImage parses the multipart form and returns the image file, header, and suggested extension.
// Validates Content-Type and size. Caller must close the returned file.
func ParseImage(r *http.Request, fieldName string) (file io.ReadCloser, header *multipart.FileHeader, ext string, err error) {
	if fieldName == "" {
		fieldName = FormFieldImage
	}
	
	if err = r.ParseMultipartForm(MaxUploadSize); err != nil {
		return nil, nil, "", err
	}
	
	f, fh, err := r.FormFile(fieldName)
	
	if err != nil {
		return nil, nil, "", err
	}
	
	defer func() {
		if err != nil {
			f.Close()
		}
	}()
	
	if fh.Size > MaxUploadSize {
		return nil, nil, "", ErrTooLarge
	}
	
	ct := fh.Header.Get("Content-Type")
	
	if ct == "" {
		ct = "application/octet-stream"
	}
	ct = strings.TrimSpace(strings.Split(ct, ";")[0])

	// When client sends application/octet-stream (e.g. MultipartFile.fromBytes), infer type from filename.
	if ct == "application/octet-stream" {
		ct = contentTypeFromFilename(fh.Filename)
	}
	if !AllowedImageTypes[ct] {
		return nil, nil, "", ErrInvalidType
	}
	
	ext = ExtensionByContentType(ct)
	
	return f, fh, ext, nil
}

// SaveFile writes src to uploadDir/relPath and creates parent directories if needed.
// relPath should be a relative path like "profiles/uuid.jpg" (no leading slash, no "..").
func SaveFile(uploadDir, relPath string, src io.Reader) error {
	if err := validateRelPath(relPath); err != nil {
		return err
	}
	
	fullPath := filepath.Join(uploadDir, filepath.FromSlash(relPath))
	
	// Ensure the parent directories for the destination file exist,
	// creating them with permission 0755 (owner: read/write/execute, group and others: read/execute) if necessary.
	if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
		return err
	}
	
	dst, err := os.Create(fullPath)
	
	if err != nil {
		return err
	}
	
	defer dst.Close()
	
	_, err = io.Copy(dst, src)
	
	return err
}

// DeleteFile removes the file at uploadDir/relPath if it exists.
func DeleteFile(uploadDir, relPath string) error {
	if relPath == "" {
		return nil
	}
	
	if err := validateRelPath(relPath); err != nil {
		return err // ErrPathEscape
	}
	
	fullPath := filepath.Join(uploadDir, filepath.FromSlash(relPath))
	_ = os.Remove(fullPath)
	
	return nil
}

// ServeFile streams the file at uploadDir/relPath to w with the appropriate Content-Type.
// Returns errPathEscape if relPath escapes the upload directory.
func ServeFile(w http.ResponseWriter, uploadDir, relPath string) error {
	if err := validateRelPath(relPath); err != nil {
		return err
	}
	
	fullPath := filepath.Join(uploadDir, filepath.FromSlash(relPath))
	
	// Ensure resolved path is still under uploadDir (no .. escape).
	absUpload, _ := filepath.Abs(uploadDir)
	absFull, _ := filepath.Abs(fullPath)
	
	if !strings.HasPrefix(absFull, absUpload) {
		return ErrPathEscape
	}
	
	f, err := os.Open(fullPath)
	
	if err != nil {
		return err
	}
	
	defer f.Close()
	
	info, err := f.Stat()
	
	if err != nil {
		return err
	}
	
	if info.IsDir() {
		return os.ErrNotExist
	}
	
	ct := mime.TypeByExtension(filepath.Ext(info.Name()))
	
	if ct == "" {
		ct = "application/octet-stream"
	}
	
	w.Header().Set("Content-Type", ct)
	_, err = io.Copy(w, f)
	
	return err
}

func validateRelPath(relPath string) error {
	cleaned := filepath.Clean(filepath.FromSlash(relPath))

	if cleaned == "" || cleaned == "." {
		return ErrPathEscape
	}
	
	if strings.HasPrefix(cleaned, "..") || filepath.IsAbs(cleaned) {
		return ErrPathEscape
	}
	
	return nil
}
