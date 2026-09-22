package attendance

import "time"

// CivilDate returns the calendar date of instant in loc, encoded as midnight UTC.
// Postgres DATE columns should be written from that UTC midnight so the zone
// offset cannot shift the stored day.
func CivilDate(instant time.Time, loc *time.Location) time.Time {
	local := instant.In(loc)
	return time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, time.UTC)
}
