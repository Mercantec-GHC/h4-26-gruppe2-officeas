# Build stage
FROM golang:1.25-alpine AS build

WORKDIR /app

# Install git and swag (needed for Swagger docs generation)
RUN apk add --no-cache git

# Install swag CLI for generating Swagger docs
RUN go install github.com/swaggo/swag/cmd/swag@latest

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Update go.sum with new dependencies
RUN go mod tidy

# Generate Swagger documentation (creates docs/ directory with docs.go)
RUN swag init -g main.go

# Download dependencies again (in case docs package needs them)
RUN go mod download

# Build the application (docs.go will be compiled into binary)
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary and Swagger docs from build stage
COPY --from=build /app/main .
COPY --from=build /app/docs ./docs

# Expose port 8080
EXPOSE 8080

# Run the binary
CMD ["./main"]
