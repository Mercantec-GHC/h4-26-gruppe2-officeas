# H4 - YourOffice
Office Management System med Flutter frontend og Go backend

## 🚀 Getting Started

### Prerequisites

- Docker og Docker Compose installeret
- Git

### Start projektet

1. **Sæt database URL op:**
   - Opret eller opdater `gobackend/.env` med din PostgreSQL connection string:
   ```env
   DATABASE_URL=postgres://user:password@host:port/database
   ```

2. **Start alle services:**
   ```bash
   docker compose up --build
   ```

3. **Tjek at alt kører:**
   ```bash
   docker compose ps
   ```

### Services

Efter opstart er følgende services tilgængelige:

- **Nginx Reverse Proxy:** `http://localhost:8080`
- **Flutter Web App:** `http://localhost:8080/` (gennem nginx)
- **Go Backend API:** `http://localhost:8080/api/` (gennem nginx)
- **Swagger UI:** `http://localhost:8080/swagger/` eller `http://localhost:8080/api/swagger/`

### API Endpoints

Alle API endpoints er tilgængelige gennem nginx på `/api/` prefix:

- Health Check: `GET http://localhost:8080/api/health`
- Departments: `GET http://localhost:8080/api/departments`
- Users: `GET http://localhost:8080/api/users`
- Tickets: `GET http://localhost:8080/api/tickets`

## 📚 Swagger API Documentation

Swagger UI er tilgængelig på:

**Primary URL:**
```
http://localhost:8080/swagger/
```

## 🛠️ Development

### Genstart services

```bash
# Genstart alle services
docker compose restart

# Genstart specifik service
docker compose restart backend
docker compose restart nginx
```

### Se logs

```bash
# Alle logs
docker compose logs -f

# Specifik service
docker compose logs -f backend
docker compose logs -f nginx
```

### Stop services

```bash
docker compose down
```

### Rebuild efter kode ændringer

```bash
# Rebuild og restart
docker compose up --build
```

## YourOffice Domain Model

```mermaid
classDiagram
    class User {
        +Guid Id
        +string Name
        +string Email
        +string PasswordHash
        +Guid DepartmentId
        +int FeedbackRating
        +DateTime CreatedAt
        +DateTime UpdatedAt
    }

    class Department {
        +Guid Id
        +string Name
        +DateTime CreatedAt
        +DateTime UpdatedAt
    }

    class Ticket {
        +Guid Id
        +string Title
        +string Description
        +TicketStatus Status
        +Guid CreatedByUserId
        +Guid? AssignedToUserId
        +DateTime CreatedAt
        +DateTime UpdatedAt
        +DateTime? ResolvedAt
    }

    class TicketStatus {
        <<enumeration>>
        OPEN
        IN_PROGRESS
        RESOLVED
        CLOSED
        CANCELLED
    }

    class Feedback {
        +Guid Id
        +Guid DepartmentId
        +int Rating
        +DateTime CreatedAt
    }

    class Shift {
        +Guid Id
        +Guid UserId
        +DateTime StartTime
        +DateTime EndTime
        +DateTime CreatedAt
        +DateTime UpdatedAt
    }

    class AbsenceRequest {
        +Guid Id
        +Guid UserId
        +AbsenceType Type
        +DateTime StartDate
        +DateTime EndDate
        +Guid? ShiftId
        +RequestStatus Status
        +DateTime CreatedAt
        +DateTime? ReviewedAt
        +Guid? ReviewedByUserId
    }

    class AbsenceType {
        <<enumeration>>
        SICK_LEAVE
        VACATION
        PERSONAL_LEAVE
        OTHER
    }

    class RequestStatus {
        <<enumeration>>
        PENDING
        APPROVED
        REJECTED
    }

    class TicketComment {
        +Guid Id
        +Guid TicketId
        +Guid UserId
        +string Content
        +DateTime CreatedAt
        +DateTime UpdatedAt
    }

    class AbsenceRequestComment {
        +Guid Id
        +Guid AbsenceRequestId
        +Guid UserId
        +string Content
        +DateTime CreatedAt
        +DateTime UpdatedAt
    }

    class Notification {
        +Guid Id
        +Guid UserId
        +string Title
        +string Message
        +NotificationType Type
        +DateTime CreatedAt
        +DateTime? ReadAt
        +Guid? RelatedEntityId
        +string? RelatedEntityType
    }

    class NotificationType {
        <<enumeration>>
        TICKET_ASSIGNED
        TICKET_UPDATED
        TICKET_COMMENTED
        ABSENCE_APPROVED
        ABSENCE_REJECTED
        ABSENCE_COMMENTED
        SHIFT_CREATED
        SHIFT_CANCELLED
        FEEDBACK_RECEIVED
        SYSTEM_ANNOUNCEMENT
    }

    User "*" --> "1" Department : belongs to
    User "1" --> "*" Ticket : creates
    User "1" --> "*" Ticket : assigned to
    User "1" --> "*" Shift : has
    User "1" --> "*" AbsenceRequest : requests
    User "1" --> "*" Notification : receives
    Department "1" --> "*" Feedback : receives
    Ticket "1" --> "*" TicketComment : has
    Ticket --> TicketStatus : uses
    TicketComment "*" --> "1" User : created by
    AbsenceRequest "1" --> "*" AbsenceRequestComment : has
    AbsenceRequest --> AbsenceType : uses
    AbsenceRequest --> RequestStatus : uses
    AbsenceRequest "*" --> "0..1" Shift : cancels
    AbsenceRequestComment "*" --> "1" User : created by
    Notification --> NotificationType : uses
```