package api

import (
	"encoding/json"
	"net/http"
	"team-sync-web/internal/models"
	"team-sync-web/internal/ssh"
)

func (s *Server) handleMachines(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		machines, err := s.DB.ListMachines()
		if err != nil {
			writeError(w, 500, err.Error())
			return
		}
		if machines == nil {
			machines = []models.Machine{}
		}
		writeJSON(w, 200, machines)

	case http.MethodPost:
		var m models.Machine
		if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
			writeError(w, 400, "Invalid JSON")
			return
		}
		if m.Name == "" || m.User == "" || m.Host == "" {
			writeError(w, 400, "name, user, and host are required")
			return
		}
		if m.Port == 0 {
			m.Port = 22
		}
		if err := s.DB.CreateMachine(&m); err != nil {
			writeError(w, 500, err.Error())
			return
		}
		writeJSON(w, 201, m)

	default:
		writeError(w, 405, "Method not allowed")
	}
}

func (s *Server) handleMachineByID(w http.ResponseWriter, r *http.Request) {
	id, action := extractID(r.URL.Path, "/api/machines")
	if id == 0 {
		writeError(w, 400, "Invalid machine ID")
		return
	}

	if action == "test" && r.Method == http.MethodPost {
		s.testMachineSSH(w, id)
		return
	}

	if action == "browse" && r.Method == http.MethodGet {
		s.browseMachineFS(w, r, id)
		return
	}

	switch r.Method {
	case http.MethodGet:
		m, err := s.DB.GetMachine(id)
		if err != nil {
			writeError(w, 404, "Machine not found")
			return
		}
		writeJSON(w, 200, m)

	case http.MethodPut:
		var m models.Machine
		if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
			writeError(w, 400, "Invalid JSON")
			return
		}
		m.ID = id
		if m.Name == "" || m.User == "" || m.Host == "" {
			writeError(w, 400, "name, user, and host are required")
			return
		}
		if m.Port == 0 {
			m.Port = 22
		}
		if err := s.DB.UpdateMachine(&m); err != nil {
			writeError(w, 500, err.Error())
			return
		}
		writeJSON(w, 200, m)

	case http.MethodDelete:
		if err := s.DB.DeleteMachine(id); err != nil {
			writeError(w, 500, err.Error())
			return
		}
		writeJSON(w, 200, map[string]string{"status": "deleted"})

	default:
		writeError(w, 405, "Method not allowed")
	}
}

func (s *Server) browseMachineFS(w http.ResponseWriter, r *http.Request, machineID int64) {
	m, err := s.DB.GetMachine(machineID)
	if err != nil {
		writeError(w, 404, "Machine not found")
		return
	}
	path := r.URL.Query().Get("path")
	result := ssh.Browse(m, path)
	if result.Error != "" {
		writeJSON(w, 200, result) // return error in body, not HTTP error
		return
	}
	writeJSON(w, 200, result)
}

func (s *Server) testMachineSSH(w http.ResponseWriter, machineID int64) {
	m, err := s.DB.GetMachine(machineID)
	if err != nil {
		writeError(w, 404, "Machine not found")
		return
	}
	result := ssh.Check(m)
	writeJSON(w, 200, result)
}
