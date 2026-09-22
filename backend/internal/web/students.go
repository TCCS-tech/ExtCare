package web

import (
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v3"

	"tccs-checkin/internal/db"
	"tccs-checkin/internal/pdfcards"
	"tccs-checkin/internal/students"
)

type studentBody struct {
	StudentID string `json:"student_id"`
	Name      string `json:"name"`
	Grade     string `json:"grade"`
}

type studentPatch struct {
	Name   *string `json:"name"`
	Grade  *string `json:"grade"`
	Active *bool   `json:"active"`
}

func (s *Server) listStudents(c fiber.Ctx) error {
	rows, err := s.q.ListStudents(c.Context())
	if err != nil {
		return s.fail(c, err)
	}
	out := make([]fiber.Map, 0, len(rows))
	for _, row := range rows {
		out = append(out, studentJSON(row))
	}
	return c.JSON(fiber.Map{"students": out})
}

func (s *Server) createStudent(c fiber.Ctx) error {
	var body studentBody
	if err := c.Bind().Body(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Request body must be JSON."})
	}
	id, name, grade, err := cleanStudent(body.StudentID, body.Name, body.Grade)
	if err != nil {
		return s.fail(c, err)
	}
	row, err := s.q.CreateStudent(c.Context(), db.CreateStudentParams{
		StudentID: id,
		Name:      name,
		Grade:     grade,
	})
	if isUnique(err) {
		return s.fail(c, pub(fiber.StatusConflict, "That student ID is already in use."))
	}
	if err != nil {
		return s.fail(c, err)
	}
	return c.Status(fiber.StatusCreated).JSON(studentJSON(row))
}

func (s *Server) patchStudent(c fiber.Ctx) error {
	id, err := strconv.ParseInt(c.Params("id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Unknown student."})
	}
	var body studentPatch
	if err := c.Bind().Body(&body); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Request body must be JSON."})
	}
	if body.Name == nil && body.Grade == nil && body.Active == nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Nothing to update."})
	}
	if (body.Name == nil) != (body.Grade == nil) {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Enter both name and grade."})
	}
	return s.patchStudentFields(c, id, body)
}

func (s *Server) patchStudentFields(c fiber.Ctx, id int64, body studentPatch) error {
	ctx := c.Context()
	var row db.Student
	var found bool
	err := s.withTx(ctx, func(q *db.Queries) error {
		if body.Name != nil {
			name, err := cleanName(*body.Name)
			if err != nil {
				return err
			}
			grade, err := cleanGrade(*body.Grade)
			if err != nil {
				return err
			}
			row, err = q.UpdateStudent(ctx, db.UpdateStudentParams{ID: id, Name: name, Grade: grade})
			if isNoRows(err) {
				return pub(fiber.StatusNotFound, "Student not found.")
			}
			if err != nil {
				return err
			}
			found = true
		}
		if body.Active != nil {
			updated, err := q.SetStudentActive(ctx, db.SetStudentActiveParams{ID: id, Active: *body.Active})
			if isNoRows(err) {
				return pub(fiber.StatusNotFound, "Student not found.")
			}
			if err != nil {
				return err
			}
			row = updated
			found = true
		}
		return nil
	})
	if err != nil {
		return s.fail(c, err)
	}
	if !found {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "Student not found."})
	}
	return c.JSON(studentJSON(row))
}

func (s *Server) studentCards(c fiber.Ctx) error {
	rows, err := s.q.ListActiveStudents(c.Context())
	if err != nil {
		return s.fail(c, err)
	}
	if len(rows) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "There are no active students to print."})
	}
	cards := make([]pdfcards.Card, len(rows))
	for i, row := range rows {
		cards[i] = pdfcards.Card{StudentID: row.StudentID, Name: row.Name, Grade: row.Grade}
	}
	pdf, err := pdfcards.Render(cards)
	if err != nil {
		return s.fail(c, err)
	}
	c.Set("Content-Type", "application/pdf")
	c.Set("Content-Disposition", `inline; filename="tccs-student-cards.pdf"`)
	return c.Send(pdf)
}

func studentJSON(row db.Student) fiber.Map {
	return fiber.Map{
		"id":         row.ID,
		"student_id": row.StudentID,
		"name":       row.Name,
		"grade":      row.Grade,
		"active":     row.Active,
	}
}

func cleanStudent(rawID, rawName, rawGrade string) (string, string, string, error) {
	id, err := students.NormalizeID(rawID)
	if err != nil {
		return "", "", "", pub(fiber.StatusBadRequest, "Student ID must be 2–32 letters or numbers.")
	}
	name, err := cleanName(rawName)
	if err != nil {
		return "", "", "", err
	}
	grade, err := cleanGrade(rawGrade)
	if err != nil {
		return "", "", "", err
	}
	return id, name, grade, nil
}

func cleanName(raw string) (string, error) {
	name := strings.Join(strings.Fields(raw), " ")
	if name == "" || len([]rune(name)) > 80 {
		return "", pub(fiber.StatusBadRequest, "Name must be 1–80 characters.")
	}
	return name, nil
}

func cleanGrade(raw string) (string, error) {
	grade := strings.Join(strings.Fields(raw), " ")
	if grade == "" || len([]rune(grade)) > 20 {
		return "", pub(fiber.StatusBadRequest, "Grade must be 1–20 characters.")
	}
	return grade, nil
}
