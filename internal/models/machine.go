package models

import "time"

type Machine struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	User      string    `json:"user"`
	Host      string    `json:"host"`
	Port      int       `json:"port"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
