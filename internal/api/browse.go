package api

import (
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type fileEntry struct {
	Name  string `json:"name"`
	Path  string `json:"path"`
	IsDir bool   `json:"is_dir"`
	Size  int64  `json:"size"`
}

func (s *Server) handleBrowse(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, 405, "Method not allowed")
		return
	}

	dir := r.URL.Query().Get("path")
	if dir == "" {
		home, _ := os.UserHomeDir()
		dir = home
	}

	// Expand ~ to home dir
	if strings.HasPrefix(dir, "~") {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, dir[1:])
	}

	dir = filepath.Clean(dir)

	info, err := os.Stat(dir)
	if err != nil {
		writeError(w, 400, "Path not found: "+dir)
		return
	}
	if !info.IsDir() {
		dir = filepath.Dir(dir)
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		writeError(w, 400, "Cannot read directory: "+err.Error())
		return
	}

	var files []fileEntry
	for _, e := range entries {
		// Skip hidden files
		if strings.HasPrefix(e.Name(), ".") {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		files = append(files, fileEntry{
			Name:  e.Name(),
			Path:  filepath.Join(dir, e.Name()),
			IsDir: e.IsDir(),
			Size:  info.Size(),
		})
	}

	// Dirs first, then files, alphabetical
	sort.Slice(files, func(i, j int) bool {
		if files[i].IsDir != files[j].IsDir {
			return files[i].IsDir
		}
		return strings.ToLower(files[i].Name) < strings.ToLower(files[j].Name)
	})

	result := map[string]interface{}{
		"current": dir,
		"parent":  filepath.Dir(dir),
		"entries": files,
	}
	writeJSON(w, 200, result)
}
