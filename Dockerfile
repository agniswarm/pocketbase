# UI build stage - build the admin dashboard UI
FROM node:20.17-alpine AS ui-builder

WORKDIR /app

# Copy UI package files first for better layer caching
COPY ui/package.json ui/package-lock.json ./ui/

# Install UI dependencies
WORKDIR /app/ui
RUN npm ci

# Copy UI source files
WORKDIR /app
COPY ui/ ./ui/

# Build the UI
WORKDIR /app/ui
RUN npm run build

# Go build stage - build the PocketBase application
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Copy the built UI from the ui-builder stage (overwrites any existing dist)
COPY --from=ui-builder /app/ui/dist ./ui/dist

# Build the application
# Using the examples/base/main.go as the entry point
# Build from root so the ui package can be resolved correctly
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/pocketbase ./examples/base

# CA certificates stage - needed for scratch image
FROM alpine:latest AS certs
RUN apk --no-cache add ca-certificates

# Runtime stage - using scratch for minimal image size
FROM scratch

# Copy CA certificates from alpine for HTTPS support
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the binary from builder
COPY --from=builder /app/pocketbase /app/pocketbase

# Expose the default PocketBase port
EXPOSE 8090

# Run the application
ENTRYPOINT ["/app/pocketbase"]
CMD ["serve", "--http=0.0.0.0:8090"]
