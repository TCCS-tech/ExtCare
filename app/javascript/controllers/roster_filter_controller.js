import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "query", "grade", "focus" ]

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
    this.timer = setTimeout(() => this.submitField(field), 200)
  }

  submitNow(event) {
    clearTimeout(this.timer)
    this.submitField(event.target)
  }

  submitGrade(event) {
    const grade = event.params.grade
    this.gradeTarget.value = grade === "all" || grade == null ? "" : grade
    this.submitField(this.queryTarget)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  submitField(field) {
    if (this.hasFocusTarget && field?.name) this.focusTarget.value = field.name
    this.element.requestSubmit()
  }
}
