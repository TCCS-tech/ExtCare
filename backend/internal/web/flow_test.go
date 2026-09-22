package web

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"tccs-checkin/internal/config"
	"tccs-checkin/internal/db"
	"tccs-checkin/internal/schema"
)

func TestAttendanceFlow(t *testing.T) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		t.Skip("DATABASE_URL not set")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	if err := pool.Ping(ctx); err != nil {
		t.Fatal(err)
	}
	if err := schema.Apply(ctx, pool); err != nil {
		t.Fatal(err)
	}

	app := New(pool, config.Config{Location: time.UTC, SessionTTL: 24 * time.Hour})
	email := fmt.Sprintf("flow%d@test.local", time.Now().UnixNano())
	const password = "password123"
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.New(pool).CreateAdmin(ctx, db.CreateAdminParams{Email: email, PasswordHash: string(hash)}); err != nil {
		t.Fatal(err)
	}

	status, _, _ := do(t, app, http.MethodPost, "/api/admin/login", "", map[string]string{
		"email": email, "password": "wrong-password",
	})
	if status != http.StatusUnauthorized {
		t.Fatalf("bad password status %d", status)
	}

	status, _, cookie := do(t, app, http.MethodPost, "/api/admin/login", "", map[string]string{
		"email": email, "password": password,
	})
	if status != http.StatusOK || cookie == "" {
		t.Fatalf("login status %d cookie %q", status, cookie)
	}

	status, _, _ = do(t, app, http.MethodGet, "/api/admin/students", "", nil)
	if status != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", status)
	}

	studentID := fmt.Sprintf("B%d", time.Now().UnixNano()%1_000_000_000)
	status, created, _ := do(t, app, http.MethodPost, "/api/admin/students", cookie, map[string]string{
		"student_id": strings.ToLower(studentID),
		"name":       "Bobby Smith",
		"grade":      "6th",
	})
	if status != http.StatusCreated {
		t.Fatalf("create student %d %v", status, created)
	}
	internalID := int64(created["id"].(float64))

	status, lookup, _ := do(t, app, http.MethodGet, "/api/students/"+studentID, "", nil)
	if status != http.StatusOK || lookup["grade_phrase"] != "6th grade" || lookup["checked_in"] != false {
		t.Fatalf("lookup %d %v", status, lookup)
	}

	status, _, _ = do(t, app, http.MethodPost, "/api/checkin", "", map[string]string{"student_id": "no!"})
	if status != http.StatusBadRequest {
		t.Fatalf("bad id status %d", status)
	}

	status, checked, _ := do(t, app, http.MethodPost, "/api/checkin", "", map[string]string{"student_id": studentID})
	if status != http.StatusCreated || checked["name"] != "Bobby Smith" {
		t.Fatalf("checkin %d %v", status, checked)
	}

	status, again, _ := do(t, app, http.MethodPost, "/api/checkin", "", map[string]string{"student_id": studentID})
	if status != http.StatusConflict || !strings.Contains(again["error"].(string), "already checked in") {
		t.Fatalf("second checkin %d %v", status, again)
	}

	otherID := studentID + "X"
	status, _, _ = do(t, app, http.MethodPost, "/api/admin/students", cookie, map[string]string{
		"student_id": otherID, "name": "Sam Lee", "grade": "K",
	})
	if status != http.StatusCreated {
		t.Fatalf("create other %d", status)
	}
	status, early, _ := do(t, app, http.MethodPost, "/api/checkout", "", map[string]string{"student_id": otherID})
	if status != http.StatusConflict || !strings.Contains(early["error"].(string), "not checked in") {
		t.Fatalf("early checkout %d %v", status, early)
	}

	status, out, _ := do(t, app, http.MethodPost, "/api/checkout", "", map[string]string{"student_id": studentID})
	if status != http.StatusOK || out["checkout_at"] == nil {
		t.Fatalf("checkout %d %v", status, out)
	}
	status, _, _ = do(t, app, http.MethodPost, "/api/checkout", "", map[string]string{"student_id": studentID})
	if status != http.StatusConflict {
		t.Fatalf("second checkout %d", status)
	}

	status, _, _ = do(t, app, http.MethodPatch, fmt.Sprintf("/api/admin/students/%d", internalID), cookie, map[string]any{"active": false})
	if status != http.StatusOK {
		t.Fatalf("disable %d", status)
	}
	status, missing, _ := do(t, app, http.MethodPost, "/api/checkin", "", map[string]string{"student_id": studentID})
	if status != http.StatusNotFound {
		t.Fatalf("disabled checkin %d %v", status, missing)
	}

	raw := doRaw(t, app, http.MethodGet, "/api/admin/student-cards", cookie)
	if !bytes.HasPrefix(raw, []byte("%PDF-")) {
		t.Fatalf("pdf header %q", raw[:min(12, len(raw))])
	}

	day := time.Now().UTC().Format("2006-01-02")
	status, roster, _ := do(t, app, http.MethodGet, "/api/admin/attendance?date="+day, cookie, nil)
	if status != http.StatusOK {
		t.Fatalf("roster %d %v", status, roster)
	}
	found := false
	for _, item := range roster["attendance"].([]any) {
		row := item.(map[string]any)
		if row["student_id"] == studentID {
			found = true
		}
	}
	if !found {
		t.Fatalf("roster missing %s: %v", studentID, roster)
	}
}

func do(t *testing.T, app *fiber.App, method, path, cookie string, body any) (int, map[string]any, string) {
	t.Helper()
	raw := doRaw(t, app, method, path, cookie, body)
	var payload map[string]any
	if len(raw) > 0 && raw[0] == '{' {
		if err := json.Unmarshal(raw, &payload); err != nil {
			t.Fatal(err)
		}
	}
	return lastStatus, payload, lastCookie
}

var lastStatus int
var lastCookie string

func doRaw(t *testing.T, app *fiber.App, method, path, cookie string, body ...any) []byte {
	t.Helper()
	var buf bytes.Buffer
	if len(body) > 0 && body[0] != nil {
		if err := json.NewEncoder(&buf).Encode(body[0]); err != nil {
			t.Fatal(err)
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	if buf.Len() > 0 {
		req.Header.Set("Content-Type", "application/json")
	}
	if cookie != "" {
		req.Header.Set("Cookie", cookie)
	}
	resp, err := app.Test(req, fiber.TestConfig{Timeout: 15 * time.Second, FailOnTimeout: true})
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	lastStatus = resp.StatusCode
	lastCookie = ""
	for _, c := range resp.Cookies() {
		if c.Name == cookieName && c.Value != "" {
			lastCookie = cookieName + "=" + c.Value
		}
	}
	return raw
}
