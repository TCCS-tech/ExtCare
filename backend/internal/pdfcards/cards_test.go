package pdfcards

import "testing"

func TestRenderPageBreakAndHeader(t *testing.T) {
	cards := make([]Card, 13)
	for i := range cards {
		cards[i] = Card{
			StudentID: fmtID(i),
			Name:      "Student Name",
			Grade:     "6th",
		}
	}
	cards[0] = Card{StudentID: "KID1", Name: "Ada López", Grade: "K"}
	out, err := Render(cards)
	if err != nil {
		t.Fatal(err)
	}
	if len(out) < 8 || string(out[:5]) != "%PDF-" {
		t.Fatalf("not a pdf, len=%d", len(out))
	}
	if _, err := Render(nil); err == nil {
		t.Fatal("expected error for empty list")
	}
}

func fmtID(i int) string {
	return "S" + string(rune('A'+i%26)) + string(rune('0'+i%10))
}
