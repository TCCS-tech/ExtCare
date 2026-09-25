import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "clock", "resetButton"]

  connect() {
    if (!this.hasClockTarget || !this.hasFieldTarget) return

    this.updateClock()
    this.clockInterval = window.setInterval(() => this.updateClock(), 1000)
  }

  disconnect() {
    window.clearInterval(this.clockInterval)
  }

  updateClock() {
    const now = new Date()
    this.clockTarget.textContent = new Intl.DateTimeFormat(undefined, {
      hour: "numeric", minute: "2-digit"
    }).format(now)
    if (!this.adjustingTime) this.fieldTarget.value = this.localTimeValue(now)
  }

  showAdjustment() {
    this.adjustingTime = true
    this.fieldTarget.hidden = false
    this.resetButtonTarget.hidden = false
    this.fieldTarget.focus()
  }

  useCurrentTime() {
    this.adjustingTime = false
    this.fieldTarget.hidden = true
    this.resetButtonTarget.hidden = true
    this.updateClock()
  }

  localTimeValue(date) {
    return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`
  }

  submit(event) {
    if (!this.hasFieldTarget) return

    const form = event.target
    const name = form.querySelector('input[name="student_id"]') ? "checkin_time" :
      form.querySelector('input[name="attendance_id"]') ? "checkout_time" : null
    if (!name) return

    const input = form.querySelector(`input[name="${name}"]`)
    if (input) input.value = this.fieldTarget.value
  }
}
