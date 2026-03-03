package database

import (
	"fmt"
	"strings"
	"team-sync-web/internal/models"
	"time"
)

func (db *DB) ListTransfers(status string, limit int) ([]models.Transfer, error) {
	query := `SELECT t.id, t.machine_id, COALESCE(m.name, ''), t.direction, t.local_path, t.remote_path,
		t.status, t.bytes_total, t.bytes_done, t.files_total, t.files_done, t.speed,
		t.error_message, t.started_at, t.finished_at, t.created_at
		FROM transfers t LEFT JOIN machines m ON t.machine_id = m.id`

	var conditions []string
	var args []interface{}

	if status != "" {
		conditions = append(conditions, "t.status = ?")
		args = append(args, status)
	}

	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += " ORDER BY t.created_at DESC"

	if limit > 0 {
		query += fmt.Sprintf(" LIMIT %d", limit)
	}

	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var transfers []models.Transfer
	for rows.Next() {
		var t models.Transfer
		if err := rows.Scan(&t.ID, &t.MachineID, &t.MachineName, &t.Direction, &t.LocalPath, &t.RemotePath,
			&t.Status, &t.BytesTotal, &t.BytesDone, &t.FilesTotal, &t.FilesDone, &t.Speed,
			&t.ErrorMessage, &t.StartedAt, &t.FinishedAt, &t.CreatedAt); err != nil {
			return nil, err
		}
		transfers = append(transfers, t)
	}
	return transfers, rows.Err()
}

func (db *DB) GetTransfer(id int64) (*models.Transfer, error) {
	var t models.Transfer
	err := db.QueryRow(`SELECT t.id, t.machine_id, COALESCE(m.name, ''), t.direction, t.local_path, t.remote_path,
		t.status, t.bytes_total, t.bytes_done, t.files_total, t.files_done, t.speed,
		t.error_message, t.started_at, t.finished_at, t.created_at
		FROM transfers t LEFT JOIN machines m ON t.machine_id = m.id WHERE t.id = ?`, id).
		Scan(&t.ID, &t.MachineID, &t.MachineName, &t.Direction, &t.LocalPath, &t.RemotePath,
			&t.Status, &t.BytesTotal, &t.BytesDone, &t.FilesTotal, &t.FilesDone, &t.Speed,
			&t.ErrorMessage, &t.StartedAt, &t.FinishedAt, &t.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (db *DB) CreateTransfer(t *models.Transfer) error {
	now := time.Now()
	result, err := db.Exec(
		`INSERT INTO transfers (machine_id, direction, local_path, remote_path, status, created_at)
		VALUES (?, ?, ?, ?, ?, ?)`,
		t.MachineID, t.Direction, t.LocalPath, t.RemotePath, models.StatusPending, now,
	)
	if err != nil {
		return err
	}
	t.ID, _ = result.LastInsertId()
	t.Status = models.StatusPending
	t.CreatedAt = now
	return nil
}

func (db *DB) UpdateTransferStatus(id int64, status models.Status, errorMsg string) error {
	now := time.Now()
	switch status {
	case models.StatusRunning:
		_, err := db.Exec("UPDATE transfers SET status = ?, started_at = ? WHERE id = ?", status, now, id)
		return err
	case models.StatusCompleted, models.StatusFailed, models.StatusCancelled:
		_, err := db.Exec("UPDATE transfers SET status = ?, error_message = ?, finished_at = ? WHERE id = ?",
			status, errorMsg, now, id)
		return err
	default:
		_, err := db.Exec("UPDATE transfers SET status = ? WHERE id = ?", status, id)
		return err
	}
}

func (db *DB) UpdateTransferProgress(id int64, bytesTotal, bytesDone, filesTotal, filesDone int64, speed string) error {
	_, err := db.Exec(
		"UPDATE transfers SET bytes_total = ?, bytes_done = ?, files_total = ?, files_done = ?, speed = ? WHERE id = ?",
		bytesTotal, bytesDone, filesTotal, filesDone, speed, id,
	)
	return err
}
