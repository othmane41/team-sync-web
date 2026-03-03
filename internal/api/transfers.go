package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"team-sync-web/internal/models"
)

func (s *Server) handleTransfers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		status := r.URL.Query().Get("status")
		limitStr := r.URL.Query().Get("limit")
		limit := 0
		if limitStr != "" {
			limit, _ = strconv.Atoi(limitStr)
		}

		transfers, err := s.DB.ListTransfers(status, limit)
		if err != nil {
			writeError(w, 500, err.Error())
			return
		}
		if transfers == nil {
			transfers = []models.Transfer{}
		}
		writeJSON(w, 200, transfers)

	case http.MethodPost:
		var req struct {
			MachineID  int64            `json:"machine_id"`
			Direction  models.Direction `json:"direction"`
			LocalPath  string           `json:"local_path"`
			RemotePath string           `json:"remote_path"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, 400, "Invalid JSON")
			return
		}
		if req.MachineID == 0 || req.LocalPath == "" || req.RemotePath == "" {
			writeError(w, 400, "machine_id, local_path, and remote_path are required")
			return
		}
		if req.Direction != models.Push {
			writeError(w, 403, "Only push transfers are allowed")
			return
		}

		machine, err := s.DB.GetMachine(req.MachineID)
		if err != nil {
			writeError(w, 404, "Machine not found")
			return
		}

		t := &models.Transfer{
			MachineID:  req.MachineID,
			Direction:  req.Direction,
			LocalPath:  req.LocalPath,
			RemotePath: req.RemotePath,
		}
		if err := s.DB.CreateTransfer(t); err != nil {
			writeError(w, 500, err.Error())
			return
		}

		s.Manager.Start(t, machine)
		t.MachineName = machine.Name
		writeJSON(w, 201, t)

	default:
		writeError(w, 405, "Method not allowed")
	}
}

func (s *Server) handleTransferByID(w http.ResponseWriter, r *http.Request) {
	id, action := extractID(r.URL.Path, "/api/transfers")
	if id == 0 {
		writeError(w, 400, "Invalid transfer ID")
		return
	}

	if action == "cancel" && r.Method == http.MethodPost {
		if s.Manager.Cancel(id) {
			writeJSON(w, 200, map[string]string{"status": "cancelling"})
		} else {
			writeError(w, 404, "Transfer not active")
		}
		return
	}

	if r.Method == http.MethodGet {
		t, err := s.DB.GetTransfer(id)
		if err != nil {
			writeError(w, 404, "Transfer not found")
			return
		}
		writeJSON(w, 200, t)
		return
	}

	writeError(w, 405, "Method not allowed")
}
