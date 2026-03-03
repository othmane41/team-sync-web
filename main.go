package main

import (
	"context"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"team-sync-web/internal/api"
	"team-sync-web/internal/config"
	"team-sync-web/internal/database"
	"team-sync-web/internal/rsync"
	"team-sync-web/internal/transfer"
	"team-sync-web/web"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	if err := cfg.EnsureDataDir(); err != nil {
		log.Fatalf("create data dir: %v", err)
	}

	db, err := database.Open(cfg.DBPath())
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer db.Close()

	executor := rsync.NewExecutor(cfg.RsyncBin)
	mgr := transfer.NewManager(db, executor)
	hub := api.NewHub()

	// Fan out WebSocket messages from transfer manager
	go hub.Run(mgr.BroadcastCh)

	srv := api.NewServer(db, mgr, hub)

	// Serve embedded static files and templates
	staticFS, _ := fs.Sub(web.Content, "static")
	srv.Mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))

	// Serve layout.html for the SPA root
	srv.Mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		data, err := web.Content.ReadFile("templates/layout.html")
		if err != nil {
			http.Error(w, "template not found", 500)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write(data)
	})

	addr := fmt.Sprintf(":%d", cfg.Port)
	server := &http.Server{
		Addr:    addr,
		Handler: srv.Mux,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		log.Println("Shutting down...")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		server.Shutdown(ctx)
	}()

	log.Printf("Dynamic Horizon Sync running on http://%s", addr)
	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("server: %v", err)
	}
}
