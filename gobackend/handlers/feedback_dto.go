package handlers



type FeedbackCreateRequest struct {
	Rating  int    `json:"rating" example:"5"`
	Message *string `json:"message,omitempty" example:"Rigtig god oplevelse"`
}
