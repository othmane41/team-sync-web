package models

import "time"

type Direction string

const (
	Push Direction = "push"
	Pull Direction = "pull"
)

type Status string

const (
	StatusPending   Status = "pending"
	StatusRunning   Status = "running"
	StatusCompleted Status = "completed"
	StatusFailed    Status = "failed"
	StatusCancelled Status = "cancelled"
)

type Transfer struct {
	ID           int64      `json:"id"`
	MachineID    int64      `json:"machine_id"`
	MachineName  string     `json:"machine_name,omitempty"`
	Direction    Direction  `json:"direction"`
	LocalPath    string     `json:"local_path"`
	RemotePath   string     `json:"remote_path"`
	Status       Status     `json:"status"`
	BytesTotal   int64      `json:"bytes_total"`
	BytesDone    int64      `json:"bytes_done"`
	FilesTotal   int64      `json:"files_total"`
	FilesDone    int64      `json:"files_done"`
	Speed        string     `json:"speed"`
	ErrorMessage string     `json:"error_message,omitempty"`
	StartedAt    *time.Time `json:"started_at,omitempty"`
	FinishedAt   *time.Time `json:"finished_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

type Progress struct {
	TransferID int64  `json:"transfer_id"`
	BytesTotal int64  `json:"bytes_total"`
	BytesDone  int64  `json:"bytes_done"`
	FilesTotal int64  `json:"files_total"`
	FilesDone  int64  `json:"files_done"`
	Percent    int    `json:"percent"`
	Speed      string `json:"speed"`
	ETA        string `json:"eta"`
}
