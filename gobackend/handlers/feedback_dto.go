package handlers

// FeedbackCreateRequest is the JSON body for POST /api/feedback
type FeedbackCreateRequest struct {
	Rating       int     `json:"rating" example:"7"`
	Message      *string `json:"message,omitempty" example:"Rigtig god oplevelse"`
	DepartmentId *string `json:"department_id,omitempty" example:"e30b3e63-2c34-406c-8dd5-4e4fcff0dc51"`
	ShiftId      *string `json:"shift_id,omitempty" example:"shift-uuid-here"`
}
