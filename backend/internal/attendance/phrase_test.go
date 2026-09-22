package attendance

import "testing"

func TestGradePhrase(t *testing.T) {
	if got := GradePhrase("6th"); got != "6th grade" {
		t.Fatalf("got %q", got)
	}
	if got := GradePhrase("K"); got != "Kindergarten" {
		t.Fatalf("got %q", got)
	}
	if got := GradePhrase("Pre-K"); got != "Pre-K" {
		t.Fatalf("got %q", got)
	}
	if got := GradePhrase("6th grade"); got != "6th grade" {
		t.Fatalf("got %q", got)
	}
}

func TestConfirmSentence(t *testing.T) {
	got := ConfirmSentence("checkin", "Bobby Smith", "6th")
	if got != "Check in Bobby Smith (6th grade)?" {
		t.Fatalf("got %q", got)
	}
	got = ConfirmSentence("checkout", "Bobby Smith", "6th")
	if got != "Check out Bobby Smith (6th grade)?" {
		t.Fatalf("got %q", got)
	}
}
