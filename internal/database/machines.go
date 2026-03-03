package database

import (
	"team-sync-web/internal/models"
	"time"
)

func (db *DB) ListMachines() ([]models.Machine, error) {
	rows, err := db.Query("SELECT id, name, user, host, port, created_at, updated_at FROM machines ORDER BY name")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var machines []models.Machine
	for rows.Next() {
		var m models.Machine
		if err := rows.Scan(&m.ID, &m.Name, &m.User, &m.Host, &m.Port, &m.CreatedAt, &m.UpdatedAt); err != nil {
			return nil, err
		}
		machines = append(machines, m)
	}
	return machines, rows.Err()
}

func (db *DB) GetMachine(id int64) (*models.Machine, error) {
	var m models.Machine
	err := db.QueryRow("SELECT id, name, user, host, port, created_at, updated_at FROM machines WHERE id = ?", id).
		Scan(&m.ID, &m.Name, &m.User, &m.Host, &m.Port, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

func (db *DB) CreateMachine(m *models.Machine) error {
	now := time.Now()
	result, err := db.Exec(
		"INSERT INTO machines (name, user, host, port, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
		m.Name, m.User, m.Host, m.Port, now, now,
	)
	if err != nil {
		return err
	}
	m.ID, _ = result.LastInsertId()
	m.CreatedAt = now
	m.UpdatedAt = now
	return nil
}

func (db *DB) UpdateMachine(m *models.Machine) error {
	now := time.Now()
	_, err := db.Exec(
		"UPDATE machines SET name = ?, user = ?, host = ?, port = ?, updated_at = ? WHERE id = ?",
		m.Name, m.User, m.Host, m.Port, now, m.ID,
	)
	if err != nil {
		return err
	}
	m.UpdatedAt = now
	return nil
}

func (db *DB) DeleteMachine(id int64) error {
	_, err := db.Exec("DELETE FROM machines WHERE id = ?", id)
	return err
}
