package rsync

import (
	"bufio"
	"context"
	"fmt"
	"os/exec"
	"team-sync-web/internal/models"
)

type Executor struct {
	RsyncBin string
}

func NewExecutor(rsyncBin string) *Executor {
	return &Executor{RsyncBin: rsyncBin}
}

// Run executes an rsync transfer and sends progress updates to the channel.
// It blocks until the transfer completes or the context is cancelled.
func (e *Executor) Run(ctx context.Context, transfer *models.Transfer, machine *models.Machine, progressCh chan<- *models.Progress) error {
	args := e.buildArgs(transfer, machine)

	cmd := exec.CommandContext(ctx, e.RsyncBin, args...)

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("stderr pipe: %w", err)
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start rsync: %w", err)
	}

	// Read stdout with CR/LF splitting for progress
	scanner := bufio.NewScanner(stdout)
	scanner.Split(SplitCRLF)

	go func() {
		for scanner.Scan() {
			line := scanner.Text()
			if p := ParseProgress(line, transfer.ID); p != nil {
				select {
				case progressCh <- p:
				case <-ctx.Done():
					return
				}
			}
		}
	}()

	// Collect stderr for error messages
	var stderrBuf []byte
	go func() {
		s := bufio.NewScanner(stderr)
		for s.Scan() {
			stderrBuf = append(stderrBuf, s.Bytes()...)
			stderrBuf = append(stderrBuf, '\n')
		}
	}()

	if err := cmd.Wait(); err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return fmt.Errorf("rsync failed: %w\n%s", err, string(stderrBuf))
	}

	return nil
}

func (e *Executor) buildArgs(transfer *models.Transfer, machine *models.Machine) []string {
	sshCmd := fmt.Sprintf("ssh -p %d -o BatchMode=yes -o StrictHostKeyChecking=accept-new", machine.Port)

	args := []string{
		"-rlptDvz",
		"--progress",
		"--rsync-path", e.RsyncBin,
		"-e", sshCmd,
	}

	remote := fmt.Sprintf("%s@%s:%s", machine.User, machine.Host, transfer.RemotePath)

	if transfer.Direction == models.Push {
		args = append(args, transfer.LocalPath, remote)
	} else {
		args = append(args, remote, transfer.LocalPath)
	}

	return args
}
