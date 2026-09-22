package attendance

import "testing"
import "time"

func TestCivilDateUsesSchoolZone(t *testing.T) {
	loc, err := time.LoadLocation("America/Chicago")
	if err != nil {
		t.Fatal(err)
	}
	// 04:30 UTC is still the previous evening in Chicago.
	instant := time.Date(2026, 9, 22, 4, 30, 0, 0, time.UTC)
	got := CivilDate(instant, loc)
	if got.Format("2006-01-02") != "2026-09-21" {
		t.Fatalf("got %s", got.Format(time.RFC3339))
	}
	if got.Location() != time.UTC {
		t.Fatal("civil date should be midnight UTC")
	}
}
