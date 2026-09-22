package pdfcards

import (
	"bytes"
	_ "embed"
	"fmt"
	"sort"
	"strings"

	"github.com/go-pdf/fpdf"
	"github.com/skip2/go-qrcode"
)

//go:embed fonts/DejaVuSans.ttf
var fontRegular []byte

//go:embed fonts/DejaVuSans-Bold.ttf
var fontBold []byte

// Card is one student on the printable sheet.
type Card struct {
	StudentID string
	Name      string
	Grade     string
}

// Render builds a letter-size PDF of student cards. Each card shows the
// name, grade, student ID, and a QR code of the student ID.
func Render(cards []Card) ([]byte, error) {
	if len(cards) == 0 {
		return nil, fmt.Errorf("no cards")
	}
	sorted := append([]Card(nil), cards...)
	sort.SliceStable(sorted, func(i, j int) bool {
		ri, si := gradeRank(sorted[i].Grade)
		rj, sj := gradeRank(sorted[j].Grade)
		if ri != rj {
			return ri < rj
		}
		if si != sj {
			return si < sj
		}
		return sorted[i].Name < sorted[j].Name
	})

	pdf := fpdf.New("P", "in", "Letter", "")
	pdf.SetMargins(0, 0, 0)
	pdf.SetAutoPageBreak(false, 0)
	pdf.AddUTF8FontFromBytes("dejavu", "", fontRegular)
	pdf.AddUTF8FontFromBytes("dejavu", "B", fontBold)
	if err := pdf.Error(); err != nil {
		return nil, err
	}

	const (
		margin = 0.45
		cols   = 3
		rows   = 4
		gapX   = 0.12
		gapY   = 0.12
		pageW  = 8.5
		pageH  = 11.0
		head   = 0.38
	)
	cardW := (pageW - 2*margin - float64(cols-1)*gapX) / cols
	cardH := (pageH - 2*margin - head - float64(rows-1)*gapY) / rows

	for i, card := range sorted {
		if i%(cols*rows) == 0 {
			pdf.AddPage()
			pdf.SetFont("dejavu", "", 9)
			pdf.SetTextColor(40, 36, 32)
			pdf.Text(margin, 0.36, "TCCS Aftercare  ·  Student cards")
			pdf.Text(pageW-margin-0.7, 0.36, fmt.Sprintf("Page %d", pdf.PageNo()))
		}
		pos := i % (cols * rows)
		col := pos % cols
		row := pos / cols
		x := margin + float64(col)*(cardW+gapX)
		y := margin + head + float64(row)*(cardH+gapY)
		if err := drawCard(pdf, card, x, y, cardW, cardH); err != nil {
			return nil, err
		}
	}
	if err := pdf.Error(); err != nil {
		return nil, err
	}
	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func drawCard(pdf *fpdf.Fpdf, card Card, x, y, w, h float64) error {
	pdf.SetDrawColor(186, 176, 160)
	pdf.SetLineWidth(0.012)
	pdf.Rect(x, y, w, h, "D")

	pad := 0.1
	innerW := w - 2*pad
	textX := x + pad
	cursor := y + 0.22

	pdf.SetTextColor(28, 24, 20)
	pdf.SetFont("dejavu", "B", 11)
	lines := wrapLines(pdf, card.Name, innerW, 2)
	for _, line := range lines {
		pdf.Text(textX, cursor, line)
		cursor += 0.18
	}

	pdf.SetFont("dejavu", "", 9)
	pdf.SetTextColor(70, 62, 52)
	grade := card.Grade
	if pdf.GetStringWidth(grade) > innerW {
		grade = trimToWidth(pdf, grade, innerW)
	}
	pdf.Text(textX, cursor+0.02, grade)

	png, err := qrcode.Encode(card.StudentID, qrcode.Medium, 256)
	if err != nil {
		return err
	}
	key := "qr-" + card.StudentID
	opt := fpdf.ImageOptions{ImageType: "PNG"}
	pdf.RegisterImageOptionsReader(key, opt, bytes.NewReader(png))
	qrSize := 0.95
	qrX := x + (w-qrSize)/2
	qrY := y + h - qrSize - 0.32
	pdf.ImageOptions(key, qrX, qrY, qrSize, qrSize, false, opt, 0, "")

	pdf.SetFont("dejavu", "", 8)
	pdf.SetTextColor(40, 36, 32)
	idLabel := card.StudentID
	idW := pdf.GetStringWidth(idLabel)
	pdf.Text(x+(w-idW)/2, y+h-0.12, idLabel)
	return pdf.Error()
}

func wrapLines(pdf *fpdf.Fpdf, text string, maxW float64, maxLines int) []string {
	words := strings.Fields(text)
	if len(words) == 0 {
		return []string{""}
	}
	var lines []string
	cur := ""
	for _, word := range words {
		trial := word
		if cur != "" {
			trial = cur + " " + word
		}
		if pdf.GetStringWidth(trial) <= maxW {
			cur = trial
			continue
		}
		if cur != "" {
			lines = append(lines, cur)
		}
		cur = trimToWidth(pdf, word, maxW)
	}
	if cur != "" {
		lines = append(lines, cur)
	}
	if len(lines) > maxLines {
		lines = lines[:maxLines]
		lines[maxLines-1] = trimToWidth(pdf, lines[maxLines-1]+"…", maxW)
	}
	return lines
}

func trimToWidth(pdf *fpdf.Fpdf, text string, maxW float64) string {
	runes := []rune(text)
	for len(runes) > 0 && pdf.GetStringWidth(string(runes)) > maxW {
		runes = runes[:len(runes)-1]
	}
	if len(runes) == 0 {
		return ""
	}
	return string(runes)
}

func gradeRank(grade string) (int, string) {
	g := strings.ToLower(strings.TrimSpace(grade))
	switch {
	case strings.HasPrefix(g, "pre"):
		return -1, g
	case g == "k" || strings.HasPrefix(g, "kinder"):
		return 0, g
	default:
		n := 0
		seen := false
		for _, r := range g {
			if r < '0' || r > '9' {
				break
			}
			seen = true
			n = n*10 + int(r-'0')
		}
		if seen {
			return n, g
		}
		return 100, g
	}
}
