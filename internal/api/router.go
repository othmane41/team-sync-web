package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"team-sync-web/internal/database"
	"team-sync-web/internal/transfer"
)

type Server struct {
	DB      *database.DB
	Manager *transfer.Manager
	Hub     *Hub
	Mux     *http.ServeMux
}

func NewServer(db *database.DB, mgr *transfer.Manager, hub *Hub) *Server {
	s := &Server{DB: db, Manager: mgr, Hub: hub, Mux: http.NewServeMux()}
	s.routes()
	return s
}

func (s *Server) routes() {
	s.Mux.HandleFunc("/api/machines", s.handleMachines)
	s.Mux.HandleFunc("/api/machines/", s.handleMachineByID)
	s.Mux.HandleFunc("/api/transfers", s.handleTransfers)
	s.Mux.HandleFunc("/api/transfers/", s.handleTransferByID)
	s.Mux.HandleFunc("/api/browse", s.handleBrowse)
	s.Mux.HandleFunc("/ws", s.Hub.HandleWS)
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

// extractID extracts an ID from a URL path like /api/things/123 or /api/things/123/action
func extractID(path, prefix string) (int64, string) {
	rest := strings.TrimPrefix(path, prefix)
	rest = strings.TrimPrefix(rest, "/")
	parts := strings.SplitN(rest, "/", 2)
	id, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return 0, ""
	}
	action := ""
	if len(parts) > 1 {
		action = parts[1]
	}
	return id, action
}
