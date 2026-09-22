package attendance

import "strings"

// GradePhrase turns a stored grade into the words used in the confirmation
// sentence. "6th" becomes "6th grade". Values that already say "grade",
// along with kindergarten labels, are left readable on their own.
func GradePhrase(grade string) string {
	g := strings.TrimSpace(grade)
	lower := strings.ToLower(g)
	switch {
	case g == "":
		return "unknown grade"
	case strings.Contains(lower, "grade"):
		return g
	case lower == "k" || lower == "kindergarten":
		return "Kindergarten"
	case strings.HasPrefix(lower, "pre"):
		return g
	default:
		return g + " grade"
	}
}

// ConfirmSentence is the parent-facing prompt, for example
// "Check in Bobby Smith (6th grade)?".
func ConfirmSentence(action, name, grade string) string {
	verb := "Check in"
	if action == "checkout" {
		verb = "Check out"
	}
	return verb + " " + strings.TrimSpace(name) + " (" + GradePhrase(grade) + ")?"
}
