package config

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	DatabaseURL  string
	HTTPAddr     string
	Timezone     string
	Location     *time.Location
	SessionTTL   time.Duration
	CookieSecure bool
	SeedEmail    string
	SeedPassword string
	StaticDir    string
}

func LoadDotEnv() {
	for _, path := range []string{".env", "../.env"} {
		loadFile(path)
	}
}

func loadFile(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		val = strings.TrimSpace(val)
		val = strings.Trim(val, `"'`)
		if _, exists := os.LookupEnv(key); exists {
			continue
		}
		_ = os.Setenv(key, val)
	}
}

func FromEnv() (Config, error) {
	cfg := Config{
		DatabaseURL:  os.Getenv("DATABASE_URL"),
		HTTPAddr:     envOr("HTTP_ADDR", ":8088"),
		Timezone:     envOr("APP_TIMEZONE", "America/Chicago"),
		CookieSecure: os.Getenv("COOKIE_SECURE") == "true",
		SeedEmail:    strings.ToLower(strings.TrimSpace(os.Getenv("SEED_ADMIN_EMAIL"))),
		SeedPassword: os.Getenv("SEED_ADMIN_PASSWORD"),
		StaticDir:    strings.TrimSpace(os.Getenv("STATIC_DIR")),
	}
	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}
	hours, err := strconv.Atoi(envOr("SESSION_TTL_HOURS", "168"))
	if err != nil || hours < 1 {
		return Config{}, fmt.Errorf("SESSION_TTL_HOURS must be a positive number")
	}
	cfg.SessionTTL = time.Duration(hours) * time.Hour
	loc, err := time.LoadLocation(cfg.Timezone)
	if err != nil {
		return Config{}, fmt.Errorf("APP_TIMEZONE: %w", err)
	}
	cfg.Location = loc
	return cfg, nil
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
