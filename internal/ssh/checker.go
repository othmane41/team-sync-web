package ssh

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"team-sync-web/internal/models"
	"time"
)

type Result struct {
	OK      bool   `json:"ok"`
	Message string `json:"message"`
	Latency string `json:"latency,omitempty"`
}

func Check(machine *models.Machine) *Result {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	start := time.Now()

	cmd := exec.CommandContext(ctx, "ssh",
		"-p", fmt.Sprintf("%d", machine.Port),
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=5",
		"-o", "StrictHostKeyChecking=accept-new",
		fmt.Sprintf("%s@%s", machine.User, machine.Host),
		"echo ok",
	)

	output, err := cmd.CombinedOutput()
	elapsed := time.Since(start)

	if err != nil {
		msg := strings.TrimSpace(string(output))
		if msg == "" {
			msg = err.Error()
		}
		return &Result{OK: false, Message: msg}
	}

	if strings.TrimSpace(string(output)) == "ok" {
		return &Result{
			OK:      true,
			Message: "Connection successful",
			Latency: elapsed.Round(time.Millisecond).String(),
		}
	}

	return &Result{OK: false, Message: "Unexpected response: " + strings.TrimSpace(string(output))}
}
