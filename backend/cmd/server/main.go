package main

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/jackc/pgx/v5/pgxpool"

	"tccs-checkin/internal/config"
	"tccs-checkin/internal/db"
	"tccs-checkin/internal/schema"
	"tccs-checkin/internal/web"
)

func main() {
	config.LoadDotEnv()
	cfg, err := config.FromEnv()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("database", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	pingCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	err = pool.Ping(pingCtx)
	cancel()
	if err != nil {
		slog.Error("database ping", "err", err)
		os.Exit(1)
	}
	if err := schema.Apply(ctx, pool); err != nil {
		slog.Error("schema", "err", err)
		os.Exit(1)
	}
	if err := db.New(pool).DeleteExpiredSessions(ctx); err != nil {
		slog.Error("sessions", "err", err)
		os.Exit(1)
	}
	if err := web.SeedAdmin(ctx, pool, cfg); err != nil {
		slog.Error("seed admin", "err", err)
		os.Exit(1)
	}

	app := web.New(pool, cfg)
	slog.Info("listening", "addr", cfg.HTTPAddr)
	err = app.Listen(cfg.HTTPAddr, fiber.ListenConfig{
		DisableStartupMessage: true,
		GracefulContext:       ctx,
	})
	if err != nil && !errors.Is(err, context.Canceled) {
		slog.Error("listen", "err", err)
		os.Exit(1)
	}
}
