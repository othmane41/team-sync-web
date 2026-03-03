package transfer

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"team-sync-web/internal/database"
	"team-sync-web/internal/models"
	"team-sync-web/internal/rsync"
	"time"
)

type Manager struct {
	db       *database.DB
	executor *rsync.Executor
	mu       sync.Mutex
	active   map[int64]context.CancelFunc
	// BroadcastCh receives JSON messages to send to all WebSocket clients
	BroadcastCh chan []byte
}

func NewManager(db *database.DB, executor *rsync.Executor) *Manager {
	return &Manager{
		db:          db,
		executor:    executor,
		active:      make(map[int64]context.CancelFunc),
		BroadcastCh: make(chan []byte, 256),
	}
}

func (m *Manager) Start(transfer *models.Transfer, machine *models.Machine) {
	ctx, cancel := context.WithCancel(context.Background())
	m.mu.Lock()
	m.active[transfer.ID] = cancel
	m.mu.Unlock()

	go m.run(ctx, transfer, machine)
}

func (m *Manager) Cancel(transferID int64) bool {
	m.mu.Lock()
	cancel, ok := m.active[transferID]
	m.mu.Unlock()
	if ok {
		cancel()
		return true
	}
	return false
}

func (m *Manager) IsActive(transferID int64) bool {
	m.mu.Lock()
	_, ok := m.active[transferID]
	m.mu.Unlock()
	return ok
}

func (m *Manager) run(ctx context.Context, transfer *models.Transfer, machine *models.Machine) {
	defer func() {
		m.mu.Lock()
		delete(m.active, transfer.ID)
		m.mu.Unlock()
	}()

	// Mark as running
	if err := m.db.UpdateTransferStatus(transfer.ID, models.StatusRunning, ""); err != nil {
		log.Printf("update status to running: %v", err)
		return
	}
	m.broadcastStatus(transfer.ID, models.StatusRunning, "")

	progressCh := make(chan *models.Progress, 64)

	// Throttled progress broadcast
	go m.throttleProgress(ctx, progressCh)

	err := m.executor.Run(ctx, transfer, machine, progressCh)
	close(progressCh)

	if err != nil {
		status := models.StatusFailed
		if ctx.Err() != nil {
			status = models.StatusCancelled
		}
		m.db.UpdateTransferStatus(transfer.ID, status, err.Error())
		m.broadcastStatus(transfer.ID, status, err.Error())
		return
	}

	m.db.UpdateTransferStatus(transfer.ID, models.StatusCompleted, "")
	m.broadcastStatus(transfer.ID, models.StatusCompleted, "")
}

func (m *Manager) throttleProgress(ctx context.Context, progressCh <-chan *models.Progress) {
	ticker := time.NewTicker(250 * time.Millisecond) // 4 msg/s
	defer ticker.Stop()

	var latest *models.Progress

	for {
		select {
		case p, ok := <-progressCh:
			if !ok {
				// Send final progress
				if latest != nil {
					m.sendProgress(latest)
				}
				return
			}
			latest = p
		case <-ticker.C:
			if latest != nil {
				m.sendProgress(latest)
				latest = nil
			}
		case <-ctx.Done():
			return
		}
	}
}

func (m *Manager) sendProgress(p *models.Progress) {
	m.db.UpdateTransferProgress(p.TransferID, p.BytesTotal, p.BytesDone, p.FilesTotal, p.FilesDone, p.Speed)

	msg := map[string]interface{}{
		"type": "progress",
		"data": p,
	}
	data, _ := json.Marshal(msg)
	select {
	case m.BroadcastCh <- data:
	default:
		// Drop if channel full
	}
}

func (m *Manager) broadcastStatus(transferID int64, status models.Status, errorMsg string) {
	msg := map[string]interface{}{
		"type": "status",
		"data": map[string]interface{}{
			"transfer_id":   transferID,
			"status":        status,
			"error_message": errorMsg,
		},
	}
	data, _ := json.Marshal(msg)
	select {
	case m.BroadcastCh <- data:
	default:
	}
}
