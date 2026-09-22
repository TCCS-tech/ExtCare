package students

import "testing"

func TestNormalizeID(t *testing.T) {
	cases := []struct {
		in   string
		want string
		ok   bool
	}{
		{"ab12", "AB12", true},
		{"  xy9 ", "XY9", true},
		{"https://cards.example/students/q7z", "Q7Z", true},
		{"https://cards.example/students/q7z?x=1", "Q7Z", true},
		{"A", "", false},
		{"has space", "", false},
		{"nope!", "", false},
		{"", "", false},
	}
	for _, tc := range cases {
		got, err := NormalizeID(tc.in)
		if tc.ok && (err != nil || got != tc.want) {
			t.Fatalf("NormalizeID(%q) = %q, %v; want %q", tc.in, got, err, tc.want)
		}
		if !tc.ok && err == nil {
			t.Fatalf("NormalizeID(%q) = %q; want error", tc.in, got)
		}
	}
}
