package web

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"log/slog"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v3"
	"golang.org/x/crypto/bcrypt"

	"github.com/jackc/pgx/v5/pgxpool"
	"tccs-checkin/internal/config"
	"tccs-checkin/internal/db"
)

const cookieName = "tccs_session"

type limiter struct {
	mu   sync.Mutex
	hits map[string][]time.Time
}

func (l *limiter) allow(key string) bool {
	const limit = 8
	window := 15 * time.Minute
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.hits == nil {
		l.hits = map[string][]time.Time{}
	}
	kept := l.hits[key][:0]
	for _, at := range l.hits[key] {
		if now.Sub(at) < window {
			kept = append(kept, at)
		}
	}
	if len(kept) >= limit {
		l.hits[key] = kept
		return false
	}
	l.hits[key] = append(kept, now)
	return true
}

func SeedAdmin(ctx context.Context, pool *pgxpool.Pool, cfg config.Config) error {
	if cfg.SeedEmail == "" && cfg.SeedPassword == "" {
		return nil
	}
	if cfg.SeedEmail == "" || cfg.SeedPassword == "" {
		return pub(400, "Set both SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD.")
	}
	email, err := cleanEmail(cfg.SeedEmail)
	if err != nil {
		return err
	}
	if err := cleanPassword(cfg.SeedPassword); err != nil {
		return err
	}
	q := db.New(pool)
	_, err = q.GetAdminByEmail(ctx, email)
	if err == nil {
		return nil
	}
	if !isNoRows(err) {
		return err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(cfg.SeedPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	_, err = q.CreateAdmin(ctx, db.CreateAdminParams{Email: email, PasswordHash: string(hash)})
	if err == nil {
		slog.Info("created seed staff account", "email", email)
	}
	return err
}

func (s *Server) login(c fiber.Ctx) error {
	if !s.limiter.allow("ip:" + c.IP()) {
		return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "Too many sign-in attempts. Wait a few minutes and try again."})
	}
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.Bind().Body(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Request body must be JSON."})
	}
	email, err := cleanEmail(body.Email)
	if err != nil || strings.TrimSpace(body.Password) == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Email or password is incorrect."})
	}
	if !s.limiter.allow("email:" + email) {
		return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{"error": "Too many sign-in attempts. Wait a few minutes and try again."})
	}

	admin, err := s.q.GetAdminByEmail(c.Context(), email)
	hash := s.dummyHash
	if err == nil {
		hash = []byte(admin.PasswordHash)
	} else if !isNoRows(err) {
		return s.fail(c, err)
	}
	if bcrypt.CompareHashAndPassword(hash, []byte(body.Password)) != nil || err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Email or password is incorrect."})
	}

	token, tokenHash, err := newSessionToken()
	if err != nil {
		return s.fail(c, err)
	}
	expires := time.Now().Add(s.cfg.SessionTTL)
	if err := s.q.CreateSession(c.Context(), db.CreateSessionParams{
		AdminID:   admin.ID,
		TokenHash: tokenHash,
		ExpiresAt: expires,
	}); err != nil {
		return s.fail(c, err)
	}
	s.setSessionCookie(c, token, expires)
	return c.JSON(fiber.Map{"email": admin.Email})
}

func (s *Server) logout(c fiber.Ctx) error {
	if token := c.Cookies(cookieName); token != "" {
		_ = s.q.DeleteSessionByTokenHash(c.Context(), hashToken(token))
	}
	s.clearSessionCookie(c)
	return c.JSON(fiber.Map{"ok": true})
}

func (s *Server) me(c fiber.Ctx) error {
	admin := currentAdmin(c)
	return c.JSON(fiber.Map{"email": admin.Email})
}

func (s *Server) requireAdmin(c fiber.Ctx) error {
	token := c.Cookies(cookieName)
	if token == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Sign in required."})
	}
	row, err := s.q.GetSessionByTokenHash(c.Context(), hashToken(token))
	if isNoRows(err) {
		s.clearSessionCookie(c)
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Sign in required."})
	}
	if err != nil {
		return s.fail(c, err)
	}
	if !time.Now().Before(row.ExpiresAt) {
		_ = s.q.DeleteSessionByTokenHash(c.Context(), hashToken(token))
		s.clearSessionCookie(c)
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Sign in required."})
	}
	c.Locals(localsAdmin, sessionAdmin{ID: row.AdminID, Email: row.Email})
	return c.Next()
}

func (s *Server) listStaff(c fiber.Ctx) error {
	rows, err := s.q.ListAdmins(c.Context())
	if err != nil {
		return s.fail(c, err)
	}
	out := make([]fiber.Map, 0, len(rows))
	for _, row := range rows {
		out = append(out, fiber.Map{"id": row.ID, "email": row.Email})
	}
	return c.JSON(fiber.Map{"staff": out})
}

func (s *Server) createStaff(c fiber.Ctx) error {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.Bind().Body(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Request body must be JSON."})
	}
	email, err := cleanEmail(body.Email)
	if err != nil {
		return s.fail(c, err)
	}
	if err := cleanPassword(body.Password); err != nil {
		return s.fail(c, err)
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
	if err != nil {
		return s.fail(c, err)
	}
	admin, err := s.q.CreateAdmin(c.Context(), db.CreateAdminParams{
		Email:        email,
		PasswordHash: string(hash),
	})
	if isUnique(err) {
		return s.fail(c, pub(fiber.StatusConflict, "That email is already a staff account."))
	}
	if err != nil {
		return s.fail(c, err)
	}
	return c.Status(fiber.StatusCreated).JSON(fiber.Map{"id": admin.ID, "email": admin.Email})
}

func (s *Server) deleteStaff(c fiber.Ctx) error {
	id, err := strconv.ParseInt(c.Params("id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Unknown staff account."})
	}
	me := currentAdmin(c)
	if id == me.ID {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "You can't remove the account you're signed in with."})
	}
	return s.deleteStaffLocked(c, id)
}

func (s *Server) deleteStaffLocked(c fiber.Ctx, id int64) error {
	ctx := c.Context()
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return s.fail(c, err)
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, "LOCK TABLE admins IN EXCLUSIVE MODE"); err != nil {
		return s.fail(c, err)
	}
	q := s.q.WithTx(tx)
	n, err := q.CountAdmins(ctx)
	if err != nil {
		return s.fail(c, err)
	}
	if n <= 1 {
		return s.fail(c, pub(fiber.StatusBadRequest, "Keep at least one staff account."))
	}
	rows, err := q.DeleteAdmin(ctx, id)
	if err != nil {
		return s.fail(c, err)
	}
	if rows == 0 {
		return s.fail(c, pub(fiber.StatusNotFound, "Staff account not found."))
	}
	if err := tx.Commit(ctx); err != nil {
		return s.fail(c, err)
	}
	return c.JSON(fiber.Map{"ok": true})
}

func (s *Server) setSessionCookie(c fiber.Ctx, token string, expires time.Time) {
	c.Cookie(&fiber.Cookie{
		Name:     cookieName,
		Value:    token,
		Path:     "/",
		HTTPOnly: true,
		Secure:   s.cfg.CookieSecure,
		SameSite: "Lax",
		Expires:  expires,
	})
}

func (s *Server) clearSessionCookie(c fiber.Ctx) {
	c.Cookie(&fiber.Cookie{
		Name:     cookieName,
		Value:    "",
		Path:     "/",
		HTTPOnly: true,
		Secure:   s.cfg.CookieSecure,
		SameSite: "Lax",
		Expires:  time.Unix(0, 0),
		MaxAge:   -1,
	})
}

func newSessionToken() (string, string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", "", err
	}
	token := hex.EncodeToString(buf)
	return token, hashToken(token), nil
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func cleanEmail(raw string) (string, error) {
	email := strings.ToLower(strings.TrimSpace(raw))
	if len(email) < 5 || len(email) > 254 || !strings.Contains(email, "@") || strings.ContainsAny(email, " \t") {
		return "", pub(fiber.StatusBadRequest, "Enter a valid email address.")
	}
	return email, nil
}

func cleanPassword(password string) error {
	if len(password) < 8 || len(password) > 72 {
		return pub(fiber.StatusBadRequest, "Password must be 8–72 characters.")
	}
	return nil
}
