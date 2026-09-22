package students

import (
	"errors"
	"regexp"
	"strings"
)

var ErrBadID = errors.New("bad student id")

var idPattern = regexp.MustCompile(`^[A-Z0-9]{2,32}$`)

// NormalizeID trims a scanned or typed value and uppercases it.
// A URL is reduced to its last path segment so a QR code can hold either
// the raw ID or a link that ends with the ID.
func NormalizeID(raw string) (string, error) {
	s := strings.TrimSpace(raw)
	s = strings.Trim(s, `"'`)
	if strings.Contains(s, "://") {
		if i := strings.LastIndex(s, "/"); i >= 0 && i < len(s)-1 {
			s = s[i+1:]
		}
		if i := strings.IndexAny(s, "?#"); i >= 0 {
			s = s[:i]
		}
		s = strings.TrimSpace(s)
	}
	s = strings.ToUpper(s)
	if !idPattern.MatchString(s) {
		return "", ErrBadID
	}
	return s, nil
}
