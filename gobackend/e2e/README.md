# API end-to-end tests

These tests call the real HTTP API. The backend (and database) must be running first.

## How to run

1. **Start backend and seed data**
   - With Docker: `make up` then `make seed` (from repo root). Use base URL with `/api`:  
     `E2E_BASE_URL=http://localhost:8080/api make e2e`
   - Or run backend locally: `make backend-run` (ensure `gobackend/.env` has `DATABASE_URL` and `JWT_SECRET`), then in another terminal `make seed`, then `make e2e`

2. **Run e2e**
   - From repo root: `make e2e`
   - From gobackend: `go test ./e2e -v`

Default base URL is `http://localhost:8080/api` (nginx). For backend-only use `E2E_BASE_URL=http://localhost:8080`.

## What they cover

- **Read-only:** `TestLoginAndDepartments`, `TestLoginAndUsers`, `TestLoginAndTicketsList`, `TestLoginAndShifts`, `TestLoginAndNotifications`, `TestLoginAndAbsenceRequestsList` – login then GET the list endpoint.
- **Ticket + comment CRUD:** `TestLoginAndTicketAndComment` – create ticket, add comment, update ticket, delete ticket (cleanup). Uses `mercantec@mercantec.dk`.
- **User CRUD:** `TestLoginAndUserCRUD` – create user, update, delete (cleanup). Uses e2e-manager `e2e-manager@test.com` (Ledelse).

Seed users: `mercantec@mercantec.dk` / `Password123!` and `e2e-manager@test.com` / `Password123!` (from `make seed`).
