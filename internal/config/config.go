package config

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
)

type Config struct {
	Port     int    `json:"port"`
	DataDir  string `json:"data_dir"`
	RsyncBin string `json:"rsync_bin"`
}

func DefaultConfig() *Config {
	home, _ := os.UserHomeDir()
	return &Config{
		Port:     8080,
		DataDir:  filepath.Join(home, ".dh-sync"),
		RsyncBin: findRsync(),
	}
}

// findRsync returns the absolute path to a modern rsync (3.x+).
// It prefers the Homebrew version over the outdated macOS system rsync.
func findRsync() string {
	for _, path := range []string{
		"/opt/homebrew/bin/rsync",
		"/usr/local/bin/rsync",
	} {
		if _, err := os.Stat(path); err == nil {
			return path
		}
	}
	if p, err := exec.LookPath("rsync"); err == nil {
		return p
	}
	return "rsync"
}

func Load() (*Config, error) {
	cfg := DefaultConfig()
	path := filepath.Join(cfg.DataDir, "config.json")

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return cfg, nil
		}
		return nil, err
	}

	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

func (c *Config) DBPath() string {
	return filepath.Join(c.DataDir, "dh-sync.db")
}

func (c *Config) EnsureDataDir() error {
	return os.MkdirAll(c.DataDir, 0755)
}
