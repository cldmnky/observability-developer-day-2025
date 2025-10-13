package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cldmnky/observability-developer-day-2025/go/pkg/api"
	"github.com/cldmnky/observability-developer-day-2025/go/pkg/namer"
)

func main() {
	generator := namer.MustNewDefault()
	server := api.NewServer(generator)

	port := os.Getenv("PORT")
	if port == "" {
		port = "4001"
	}

	addr := fmt.Sprintf(":%s", port)

	httpServer := &http.Server{
		Addr:    addr,
		Handler: server,
	}

	go func() {
		log.Printf("starting name generator API on %s", addr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	shutdown(httpServer)
}

func shutdown(server *http.Server) {
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}

	log.Println("server stopped")
}
