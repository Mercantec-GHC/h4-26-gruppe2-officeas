package handlers

import (
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// uuidParam returns UUID from path or writes 400 and returns zero value
func uuidParam(w http.ResponseWriter, r *http.Request, name string) (uuid.UUID, bool) {
	vars := mux.Vars(r)
	s := vars[name]

	if s == "" {
		http.Error(w, "missing path parameter: "+name, http.StatusBadRequest)
		return uuid.Nil, false
	}
	
	id, err := uuid.Parse(s)
	
	if err != nil {
		http.Error(w, "invalid UUID: "+name, http.StatusBadRequest)
		return uuid.Nil, false
	}
	
	return id, true
}
