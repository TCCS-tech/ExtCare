package web

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"tccs-checkin/internal/config"
	"tccs-checkin/internal/db"
)

const localsAdmin = "tccs.admin"

type Server struct {
	pool      *pgxpool.Pool
	q         *db.Queries
	cfg       config.Config
	dummyHash []byte
	limiter   *limiter
}

type sessionAdmin struct {
	ID    int64
	Email string
}

type statusError struct {
	code int
	msg  string
}

func (e *statusError) Error() string { return e.msg }

func pub(code int, msg string) error {
	return &statusError{code: code, msg: msg}
}

func New(pool *pgxpool.Pool, cfg config.Config) *fiber.App {
	if cfg.Location == nil {
		cfg.Location = time.Local
	}
	dummy, err := bcrypt.GenerateFromPassword([]byte("tccs-checkin-not-a-real-password"), bcrypt.DefaultCost)
	if err != nil {
		panic(err)
	}
	s := &Server{
		pool:      pool,
		q:         db.New(pool),
		cfg:       cfg,
		dummyHash: dummy,
		limiter:   &limiter{},
	}

	app := fiber.New(fiber.Config{
		BodyLimit: 1 << 20,
		ErrorHandler: func(c fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			msg := "Something went wrong."
			var fe *fiber.Error
			if errors.As(err, &fe) {
				code = fe.Code
				if code < 500 && fe.Message != "" {
					msg = fe.Message
				}
			}
			if code >= 500 {
				slog.Error("unhandled", "err", err, "path", c.Path())
			}
			return c.Status(code).JSON(fiber.Map{"error": msg})
		},
	})

	app.Use(recover.New())
	app.Use(func(c fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		c.SetContext(ctx)
		c.Set("X-Content-Type-Options", "nosniff")
		c.Set("Referrer-Policy", "no-referrer")
		if strings.HasPrefix(c.Path(), "/api") {
			c.Set("Cache-Control", "no-store")
		}
		return c.Next()
	})

	api := app.Group("/api")
	api.Get("/health", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{"ok": true})
	})
	api.Get("/students/:studentID", s.lookupStudent)
	api.Post("/checkin", s.checkin)
	api.Post("/checkout", s.checkout)
	api.Post("/admin/login", s.login)

	staff := api.Group("/admin", s.requireAdmin)
	staff.Post("/logout", s.logout)
	staff.Get("/me", s.me)
	staff.Get("/staff", s.listStaff)
	staff.Post("/staff", s.createStaff)
	staff.Delete("/staff/:id", s.deleteStaff)
	staff.Get("/students", s.listStudents)
	staff.Post("/students", s.createStudent)
	staff.Patch("/students/:id", s.patchStudent)
	staff.Get("/attendance", s.listAttendance)
	staff.Get("/student-cards", s.studentCards)

	if cfg.StaticDir != "" {
		app.Use(s.serveStatic)
	}
	return app
}

func (s *Server) fail(c fiber.Ctx, err error) error {
	var se *statusError
	if errors.As(err, &se) {
		return c.Status(se.code).JSON(fiber.Map{"error": se.msg})
	}
	var pe *pgconn.PgError
	if errors.As(err, &pe) && pe.Code == "23514" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Check the name, grade, and student ID."})
	}
	slog.Error("request failed", "err", err, "method", c.Method(), "path", c.Path())
	return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Something went wrong."})
}

func (s *Server) withTx(ctx context.Context, fn func(q *db.Queries) error) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := fn(s.q.WithTx(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func isUnique(err error) bool {
	var pe *pgconn.PgError
	return errors.As(err, &pe) && pe.Code == "23505"
}

func isNoRows(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}

func currentAdmin(c fiber.Ctx) sessionAdmin {
	admin, _ := c.Locals(localsAdmin).(sessionAdmin)
	return admin
}

func (s *Server) serveStatic(c fiber.Ctx) error {
	if c.Path() == "/api" || strings.HasPrefix(c.Path(), "/api/") {
		return c.Next()
	}
	root, err := filepath.Abs(s.cfg.StaticDir)
	if err != nil {
		return err
	}
	rel := strings.TrimPrefix(filepath.Clean("/"+c.Path()), "/")
	target := root
	if rel != "" && rel != "." {
		target = filepath.Join(root, rel)
	}
	abs, err := filepath.Abs(target)
	if err != nil || (abs != root && !strings.HasPrefix(abs, root+string(filepath.Separator))) {
		return c.SendStatus(fiber.StatusBadRequest)
	}
	info, statErr := os.Stat(abs)
	if statErr == nil && !info.IsDir() {
		return c.SendFile(abs)
	}
	if rel != "" && strings.Contains(filepath.Base(rel), ".") {
		return c.SendStatus(fiber.StatusNotFound)
	}
	return c.SendFile(filepath.Join(root, "index.html"))
}
