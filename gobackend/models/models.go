package models

import (
	"database/sql/driver"
	"time"

	"github.com/google/uuid"
)

// TicketStatus enumeration
type TicketStatus string

const (
	TicketStatusOpen       TicketStatus = "OPEN"
	TicketStatusInProgress TicketStatus = "IN_PROGRESS"
	TicketStatusResolved   TicketStatus = "RESOLVED"
	TicketStatusClosed     TicketStatus = "CLOSED"
	TicketStatusCancelled  TicketStatus = "CANCELLED"
)

func (ts TicketStatus) String() string {
	return string(ts)
}

// AbsenceType enumeration
type AbsenceType string

const (
	AbsenceTypeSickLeave AbsenceType = "SICK_LEAVE"
	AbsenceTypeVacation  AbsenceType = "VACATION"
	AbsenceTypePersonal  AbsenceType = "PERSONAL_LEAVE"
	AbsenceTypeOther     AbsenceType = "OTHER"
)

func (at AbsenceType) String() string {
	return string(at)
}

// RequestStatus enumeration
type RequestStatus string

const (
	RequestStatusPending  RequestStatus = "PENDING"
	RequestStatusApproved RequestStatus = "APPROVED"
	RequestStatusRejected RequestStatus = "REJECTED"
)

func (rs RequestStatus) String() string {
	return string(rs)
}

// NotificationType enumeration
type NotificationType string

const (
	NotificationTypeTicketAssigned     NotificationType = "TICKET_ASSIGNED"
	NotificationTypeTicketUpdated      NotificationType = "TICKET_UPDATED"
	NotificationTypeTicketCommented    NotificationType = "TICKET_COMMENTED"
	NotificationTypeAbsenceApproved    NotificationType = "ABSENCE_APPROVED"
	NotificationTypeAbsenceRejected    NotificationType = "ABSENCE_REJECTED"
	NotificationTypeAbsenceCommented   NotificationType = "ABSENCE_COMMENTED"
	NotificationTypeShiftCreated       NotificationType = "SHIFT_CREATED"
	NotificationTypeShiftCancelled     NotificationType = "SHIFT_CANCELLED"
	NotificationTypeFeedbackReceived   NotificationType = "FEEDBACK_RECEIVED"
	NotificationTypeSystemAnnouncement NotificationType = "SYSTEM_ANNOUNCEMENT"
)

func (nt NotificationType) String() string {
	return string(nt)
}

// Department represents a department in the system
type Department struct {
	Id        uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	Name      string    `gorm:"type:varchar(255);not null" json:"name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	Users     []User     `gorm:"foreignKey:DepartmentId" json:"users,omitempty"`
	Feedbacks []Feedback `gorm:"foreignKey:DepartmentId" json:"feedbacks,omitempty"`
}

// User represents a user in the system
type User struct {
	Id             uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	Name           string    `gorm:"type:varchar(255);not null" json:"name"`
	Email          string    `gorm:"type:varchar(255);not null;uniqueIndex" json:"email"`
	PasswordHash   string    `gorm:"type:varchar(255);not null" json:"-"`
	DepartmentId   uuid.UUID `gorm:"type:uuid;not null" json:"department_id"`
	FeedbackRating int       `gorm:"default:0" json:"feedback_rating"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`

	// Relations
	Department       Department              `gorm:"foreignKey:DepartmentId" json:"department,omitempty"`
	CreatedTickets   []Ticket                `gorm:"foreignKey:CreatedByUserId" json:"created_tickets,omitempty"`
	AssignedTickets  []Ticket                `gorm:"foreignKey:AssignedToUserId" json:"assigned_tickets,omitempty"`
	Shifts           []Shift                 `gorm:"foreignKey:UserId" json:"shifts,omitempty"`
	AbsenceRequests  []AbsenceRequest        `gorm:"foreignKey:UserId" json:"absence_requests,omitempty"`
	ReviewedAbsences []AbsenceRequest        `gorm:"foreignKey:ReviewedByUserId" json:"reviewed_absences,omitempty"`
	TicketComments   []TicketComment         `gorm:"foreignKey:UserId" json:"ticket_comments,omitempty"`
	AbsenceComments  []AbsenceRequestComment `gorm:"foreignKey:UserId" json:"absence_comments,omitempty"`
	Notifications    []Notification          `gorm:"foreignKey:UserId" json:"notifications,omitempty"`
}

// Ticket represents a support ticket
type Ticket struct {
	Id               uuid.UUID    `gorm:"type:uuid;primaryKey" json:"id"`
	Title            string       `gorm:"type:varchar(255);not null" json:"title"`
	Description      string       `gorm:"type:text;not null" json:"description"`
	Status           TicketStatus `gorm:"type:varchar(50);default:'OPEN'" json:"status"`
	CreatedByUserId  uuid.UUID    `gorm:"type:uuid;not null" json:"created_by_user_id"`
	AssignedToUserId *uuid.UUID   `gorm:"type:uuid" json:"assigned_to_user_id"`
	CreatedAt        time.Time    `json:"created_at"`
	UpdatedAt        time.Time    `json:"updated_at"`
	ResolvedAt       *time.Time   `json:"resolved_at"`

	// Relations
	CreatedByUser  User            `gorm:"foreignKey:CreatedByUserId" json:"created_by_user,omitempty"`
	AssignedToUser *User           `gorm:"foreignKey:AssignedToUserId" json:"assigned_to_user,omitempty"`
	Comments       []TicketComment `gorm:"foreignKey:TicketId" json:"comments,omitempty"`
}

// TicketComment represents a comment on a ticket
type TicketComment struct {
	Id        uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	TicketId  uuid.UUID `gorm:"type:uuid;not null" json:"ticket_id"`
	UserId    uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
	Content   string    `gorm:"type:text;not null" json:"content"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	Ticket Ticket `gorm:"foreignKey:TicketId" json:"ticket,omitempty"`
	User   User   `gorm:"foreignKey:UserId" json:"user,omitempty"`
}

// Feedback represents feedback from users
type Feedback struct {
	Id           uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	DepartmentId uuid.UUID `gorm:"type:uuid;not null" json:"department_id"`
	Rating       int       `gorm:"not null" json:"rating"`
	CreatedAt    time.Time `json:"created_at"`

	// Relations
	Department Department `gorm:"foreignKey:DepartmentId" json:"department,omitempty"`
}

// Shift represents a user's work shift
type Shift struct {
	Id        uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	UserId    uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
	StartTime time.Time `gorm:"type:timestamp;not null" json:"start_time"`
	EndTime   time.Time `gorm:"type:timestamp;not null" json:"end_time"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	User User `gorm:"foreignKey:UserId" json:"user,omitempty"`
}

// AbsenceRequest represents a request for absence
type AbsenceRequest struct {
	Id               uuid.UUID     `gorm:"type:uuid;primaryKey" json:"id"`
	UserId           uuid.UUID     `gorm:"type:uuid;not null" json:"user_id"`
	Type             AbsenceType   `gorm:"type:varchar(50);not null" json:"type"`
	StartDate        time.Time     `gorm:"type:date;not null" json:"start_date"`
	EndDate          time.Time     `gorm:"type:date;not null" json:"end_date"`
	ShiftId          *uuid.UUID    `gorm:"type:uuid" json:"shift_id"`
	Status           RequestStatus `gorm:"type:varchar(50);default:'PENDING'" json:"status"`
	CreatedAt        time.Time     `json:"created_at"`
	ReviewedAt       *time.Time    `json:"reviewed_at"`
	ReviewedByUserId *uuid.UUID    `gorm:"type:uuid" json:"reviewed_by_user_id"`

	// Relations
	User           User                    `gorm:"foreignKey:UserId" json:"user,omitempty"`
	ReviewedByUser *User                   `gorm:"foreignKey:ReviewedByUserId" json:"reviewed_by_user,omitempty"`
	Comments       []AbsenceRequestComment `gorm:"foreignKey:AbsenceRequestId" json:"comments,omitempty"`
}

// AbsenceRequestComment represents a comment on an absence request
type AbsenceRequestComment struct {
	Id               uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	AbsenceRequestId uuid.UUID `gorm:"type:uuid;not null" json:"absence_request_id"`
	UserId           uuid.UUID `gorm:"type:uuid;not null" json:"user_id"`
	Content          string    `gorm:"type:text;not null" json:"content"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`

	// Relations
	AbsenceRequest AbsenceRequest `gorm:"foreignKey:AbsenceRequestId" json:"absence_request,omitempty"`
	User           User           `gorm:"foreignKey:UserId" json:"user,omitempty"`
}

// Notification represents a notification for a user
type Notification struct {
	Id                uuid.UUID        `gorm:"type:uuid;primaryKey" json:"id"`
	UserId            uuid.UUID        `gorm:"type:uuid;not null" json:"user_id"`
	Title             string           `gorm:"type:varchar(255);not null" json:"title"`
	Message           string           `gorm:"type:text;not null" json:"message"`
	Type              NotificationType `gorm:"type:varchar(50);not null" json:"type"`
	CreatedAt         time.Time        `json:"created_at"`
	ReadAt            *time.Time       `json:"read_at"`
	RelatedEntityId   *uuid.UUID       `gorm:"type:uuid" json:"related_entity_id"`
	RelatedEntityType *string          `gorm:"type:varchar(50)" json:"related_entity_type"`

	// Relations
	User User `gorm:"foreignKey:UserId" json:"user,omitempty"`
}

// Implement GORM scanner and valuer interfaces for enumerations

// Scan for TicketStatus
func (ts *TicketStatus) Scan(value interface{}) error {
	if value == nil {
		return nil
	}
	*ts = TicketStatus(value.(string))
	return nil
}

// Value for TicketStatus
func (ts TicketStatus) Value() (driver.Value, error) {
	return string(ts), nil
}

// Scan for AbsenceType
func (at *AbsenceType) Scan(value interface{}) error {
	if value == nil {
		return nil
	}
	*at = AbsenceType(value.(string))
	return nil
}

// Value for AbsenceType
func (at AbsenceType) Value() (driver.Value, error) {
	return string(at), nil
}

// Scan for RequestStatus
func (rs *RequestStatus) Scan(value interface{}) error {
	if value == nil {
		return nil
	}
	*rs = RequestStatus(value.(string))
	return nil
}

// Value for RequestStatus
func (rs RequestStatus) Value() (driver.Value, error) {
	return string(rs), nil
}

// Scan for NotificationType
func (nt *NotificationType) Scan(value interface{}) error {
	if value == nil {
		return nil
	}
	*nt = NotificationType(value.(string))
	return nil
}

// Value for NotificationType
func (nt NotificationType) Value() (driver.Value, error) {
	return string(nt), nil
}
