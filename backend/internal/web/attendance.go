package web

import (
	"context"
	"time"

	"github.com/gofiber/fiber/v3"

	"tccs-checkin/internal/attendance"
	"tccs-checkin/internal/db"
	"tccs-checkin/internal/students"
)

type idBody struct {
	StudentID string `json:"student_id"`
}

func (s *Server) lookupStudent(c fiber.Ctx) error {
	view, err := s.lookup(c.Context(), c.Params("studentID"))
	if err != nil {
		return s.fail(c, err)
	}
	return c.JSON(view)
}

func (s *Server) checkin(c fiber.Ctx) error {
	var body idBody
	if err := c.Bind().Body(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Request body must be JSON."})
	}
	view, err := s.markCheckin(c.Context(), body.StudentID)
	if err != nil {
		return s.fail(c, err)
	}
	return c.Status(fiber.StatusCreated).JSON(view)
}

func (s *Server) checkout(c fiber.Ctx) error {
	var body idBody
	if err := c.Bind().Body(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Request body must be JSON."})
	}
	view, err := s.markCheckout(c.Context(), body.StudentID)
	if err != nil {
		return s.fail(c, err)
	}
	return c.JSON(view)
}

func (s *Server) listAttendance(c fiber.Ctx) error {
	day := attendance.CivilDate(time.Now(), s.cfg.Location)
	if raw := c.Query("date"); raw != "" {
		parsed, err := time.Parse("2006-01-02", raw)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Date must be YYYY-MM-DD."})
		}
		day = time.Date(parsed.Year(), parsed.Month(), parsed.Day(), 0, 0, 0, 0, time.UTC)
	}
	rows, err := s.q.ListAttendanceForDate(c.Context(), day)
	if err != nil {
		return s.fail(c, err)
	}
	out := make([]fiber.Map, 0, len(rows))
	for _, row := range rows {
		out = append(out, fiber.Map{
			"student_id":  row.StudentID,
			"name":        row.Name,
			"grade":       row.Grade,
			"checkin_at":  row.CheckinAt,
			"checkout_at": row.CheckoutAt,
		})
	}
	return c.JSON(fiber.Map{
		"date":       day.Format("2006-01-02"),
		"attendance": out,
	})
}

func (s *Server) lookup(ctx context.Context, rawID string) (fiber.Map, error) {
	id, err := students.NormalizeID(rawID)
	if err != nil {
		return nil, pub(fiber.StatusBadRequest, "Student ID must be 2–32 letters or numbers.")
	}
	st, err := s.q.GetStudentByStudentID(ctx, id)
	if isNoRows(err) || (err == nil && !st.Active) {
		if err != nil && !isNoRows(err) {
			return nil, err
		}
		return nil, pub(fiber.StatusNotFound, "No student matches that ID.")
	}
	if err != nil {
		return nil, err
	}
	day := attendance.CivilDate(time.Now(), s.cfg.Location)
	row, err := s.q.GetAttendance(ctx, db.GetAttendanceParams{StudentID: id, AttendanceDate: day})
	checkedIn := false
	checkedOut := false
	if err == nil {
		checkedIn = true
		checkedOut = row.CheckoutAt != nil
	} else if !isNoRows(err) {
		return nil, err
	}
	return fiber.Map{
		"student_id":   st.StudentID,
		"name":         st.Name,
		"grade":        st.Grade,
		"grade_phrase": attendance.GradePhrase(st.Grade),
		"checked_in":   checkedIn,
		"checked_out":  checkedOut,
	}, nil
}

func (s *Server) markCheckin(ctx context.Context, rawID string) (fiber.Map, error) {
	id, err := students.NormalizeID(rawID)
	if err != nil {
		return nil, pub(fiber.StatusBadRequest, "Student ID must be 2–32 letters or numbers.")
	}
	now := time.Now()
	day := attendance.CivilDate(now, s.cfg.Location)
	var view fiber.Map
	err = s.withTx(ctx, func(q *db.Queries) error {
		st, err := q.GetStudentByStudentID(ctx, id)
		if isNoRows(err) || (err == nil && !st.Active) {
			if err != nil && !isNoRows(err) {
				return err
			}
			return pub(fiber.StatusNotFound, "No student matches that ID.")
		}
		if err != nil {
			return err
		}
		_, err = q.GetAttendanceForUpdate(ctx, db.GetAttendanceForUpdateParams{
			StudentID:      id,
			AttendanceDate: day,
		})
		if err == nil {
			return pub(fiber.StatusConflict, st.Name+" is already checked in today.")
		}
		if !isNoRows(err) {
			return err
		}
		row, err := q.CreateAttendance(ctx, db.CreateAttendanceParams{
			StudentID:      id,
			AttendanceDate: day,
			CheckinAt:      now,
		})
		if isUnique(err) {
			return pub(fiber.StatusConflict, st.Name+" is already checked in today.")
		}
		if err != nil {
			return err
		}
		view = attendanceJSON(st.Name, st.Grade, row)
		return nil
	})
	return view, err
}

func (s *Server) markCheckout(ctx context.Context, rawID string) (fiber.Map, error) {
	id, err := students.NormalizeID(rawID)
	if err != nil {
		return nil, pub(fiber.StatusBadRequest, "Student ID must be 2–32 letters or numbers.")
	}
	now := time.Now()
	day := attendance.CivilDate(now, s.cfg.Location)
	var view fiber.Map
	err = s.withTx(ctx, func(q *db.Queries) error {
		st, err := q.GetStudentByStudentID(ctx, id)
		if isNoRows(err) || (err == nil && !st.Active) {
			if err != nil && !isNoRows(err) {
				return err
			}
			return pub(fiber.StatusNotFound, "No student matches that ID.")
		}
		if err != nil {
			return err
		}
		existing, err := q.GetAttendanceForUpdate(ctx, db.GetAttendanceForUpdateParams{
			StudentID:      id,
			AttendanceDate: day,
		})
		if isNoRows(err) {
			return pub(fiber.StatusConflict, st.Name+" is not checked in today.")
		}
		if err != nil {
			return err
		}
		if existing.CheckoutAt != nil {
			return pub(fiber.StatusConflict, st.Name+" is already checked out today.")
		}
		row, err := q.CheckoutAttendance(ctx, db.CheckoutAttendanceParams{
			StudentID:      id,
			AttendanceDate: day,
			CheckoutAt:     &now,
		})
		if isNoRows(err) {
			return pub(fiber.StatusConflict, st.Name+" is already checked out today.")
		}
		if err != nil {
			return err
		}
		view = attendanceJSON(st.Name, st.Grade, row)
		return nil
	})
	return view, err
}

func attendanceJSON(name, grade string, row db.Attendance) fiber.Map {
	return fiber.Map{
		"student_id":   row.StudentID,
		"name":         name,
		"grade":        grade,
		"grade_phrase": attendance.GradePhrase(grade),
		"date":         row.AttendanceDate.Format("2006-01-02"),
		"checkin_at":   row.CheckinAt,
		"checkout_at":  row.CheckoutAt,
	}
}
