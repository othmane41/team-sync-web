package config

import (
	"encoding/json"
	"os"
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
		RsyncBin: "rsync",
	}
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
