import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "query", "grade", "focus", "clearButton", "form" ]

  connect() {
    if (!this.hasQueryTarget || this.queryTarget.dataset.autofocus !== "true") return
    if (window.matchMedia("(max-width: 575.98px)").matches) return

    const input = this.queryTarget
    const end = input.value.length
    input.focus()
    input.setSelectionRange(end, end)
  }

  submit(event) {
    clearTimeout(this.timer)
    const field = event.target
    this.updateClearButton()
    this.timer = setTimeout(() => this.submitField(field), 200)
  }

  clearOnEscape(event) {
    if (event.key !== "Escape" || this.queryTarget.value.length === 0) return

    event.preventDefault()
    this.clearQuery()
  }

  clearQuery() {
    clearTimeout(this.timer)
    this.queryTarget.value = ""
    this.updateClearButton()
    this.submitField(this.queryTarget)
  }

  submitNow(event) {
    clearTimeout(this.timer)
    this.submitField(event.target)
  }

  submitGrade(event) {
    clearTimeout(this.timer)
    const grade = event.params.grade
    this.gradeTarget.value = grade === "all" || grade == null ? "" : grade
    this.element.querySelectorAll("[data-roster-filter-grade-param]").forEach(button => {
      const active = button.dataset.rosterFilterGradeParam === (this.gradeTarget.value || "all")
      button.classList.toggle("btn-primary", active)
      button.classList.toggle("btn-outline-primary", !active)
      button.setAttribute("aria-pressed", active)
    })
    this.submitField(this.queryTarget)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  submitField(field) {
    clearTimeout(this.timer)
    if (this.hasFocusTarget && field?.name) this.focusTarget.value = field.name
    this.updateNavigation()
    const form = this.hasFormTarget ? this.formTarget : this.element
    form.requestSubmit()
  }

  updateNavigation() {
    if (!this.hasGradeTarget) return

    // The toolbar stays in place while the results frame changes.
    this.element.querySelectorAll("a[href]").forEach(link => {
      const url = new URL(link.href)
      for (const field of [this.queryTarget, this.gradeTarget]) {
        if (field.value) url.searchParams.set(field.name, field.value)
        else url.searchParams.delete(field.name)
      }
      link.href = url.toString()
    })
  }

  updateClearButton() {
    if (this.hasClearButtonTarget) this.clearButtonTarget.hidden = this.queryTarget.value.length === 0
  }
}
