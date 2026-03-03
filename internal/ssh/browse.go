package ssh

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"team-sync-web/internal/models"
	"time"
)

type RemoteEntry struct {
	Name  string `json:"name"`
	Path  string `json:"path"`
	IsDir bool   `json:"is_dir"`
	Size  int64  `json:"size"`
}

type BrowseResult struct {
	Current string        `json:"current"`
	Parent  string        `json:"parent"`
	Entries []RemoteEntry `json:"entries"`
	Error   string        `json:"error,omitempty"`
}

// Browse lists files on a remote machine via SSH + a small Python/stat snippet.
// Falls back to ls parsing if python3 is not available.
func Browse(machine *models.Machine, path string) *BrowseResult {
	if path == "" {
		path = "~"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Use a python3 one-liner for reliable JSON output (type, size, name).
	// Falls back to ls-based if python3 is not found.
	script := fmt.Sprintf(`
p=%q
import os, json, os.path
p = os.path.expanduser(p)
p = os.path.abspath(p)
if not os.path.isdir(p):
    p = os.path.dirname(p)
entries = []
for name in sorted(os.listdir(p)):
    if name.startswith('.'):
        continue
    fp = os.path.join(p, name)
    try:
        st = os.stat(fp)
        entries.append({"name": name, "path": fp, "is_dir": os.path.isdir(fp), "size": st.st_size})
    except:
        pass
parent = os.path.dirname(p)
print(json.dumps({"current": p, "parent": parent, "entries": entries}))
`, path)

	cmd := exec.CommandContext(ctx, "ssh",
		"-p", fmt.Sprintf("%d", machine.Port),
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=5",
		"-o", "StrictHostKeyChecking=accept-new",
		fmt.Sprintf("%s@%s", machine.User, machine.Host),
		"python3", "-c", script,
	)

	output, err := cmd.Output()
	if err != nil {
		// Fallback: try with ls
		return browseFallback(ctx, machine, path)
	}

	var result BrowseResult
	if err := json.Unmarshal(output, &result); err != nil {
		return &BrowseResult{Error: "Failed to parse remote listing"}
	}
	return &result
}

func browseFallback(ctx context.Context, machine *models.Machine, path string) *BrowseResult {
	// Simple ls -1pA fallback, dirs end with /
	lsCmd := fmt.Sprintf(`cd %s 2>/dev/null || cd ~; pwd; ls -1pA 2>/dev/null`, shellQuote(path))

	cmd := exec.CommandContext(ctx, "ssh",
		"-p", fmt.Sprintf("%d", machine.Port),
		"-o", "BatchMode=yes",
		"-o", "ConnectTimeout=5",
		"-o", "StrictHostKeyChecking=accept-new",
		fmt.Sprintf("%s@%s", machine.User, machine.Host),
		lsCmd,
	)

	output, err := cmd.Output()
	if err != nil {
		return &BrowseResult{Error: fmt.Sprintf("SSH error: %v", err)}
	}

	lines := splitLines(string(output))
	if len(lines) == 0 {
		return &BrowseResult{Error: "Empty response from remote"}
	}

	current := lines[0]
	parent := parentPath(current)

	var entries []RemoteEntry
	for _, line := range lines[1:] {
		if line == "" || line[0] == '.' {
			continue
		}
		isDir := line[len(line)-1] == '/'
		name := line
		if isDir {
			name = line[:len(line)-1]
		}
		entries = append(entries, RemoteEntry{
			Name:  name,
			Path:  current + "/" + name,
			IsDir: isDir,
		})
	}

	return &BrowseResult{Current: current, Parent: parent, Entries: entries}
}

func splitLines(s string) []string {
	var lines []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			line := s[start:i]
			if len(line) > 0 && line[len(line)-1] == '\r' {
				line = line[:len(line)-1]
			}
			lines = append(lines, line)
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines
}

func parentPath(p string) string {
	if p == "/" {
		return "/"
	}
	for i := len(p) - 1; i >= 0; i-- {
		if p[i] == '/' {
			if i == 0 {
				return "/"
			}
			return p[:i]
		}
	}
	return "/"
}

func shellQuote(s string) string {
	// Simple single-quote escaping
	out := "'"
	for _, c := range s {
		if c == '\'' {
			out += `'\'`
		}
		out += string(c)
	}
	return out + "'"
}
