import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "clock", "adjustButton", "resetButton"]
  static values = { day: String }

  connect() {
    this.override = sessionStorage.getItem(this.storageKey)
    this.render()
    this.clockInterval = window.setInterval(() => this.updateClock(), 1000)
  }

  disconnect() {
    window.clearInterval(this.clockInterval)
  }

  get storageKey() {
    return `attendance-time:${this.dayValue}`
  }

  updateClock() {
    const now = new Date()
    this.clockTarget.textContent = new Intl.DateTimeFormat(undefined, {
      hour: "numeric", minute: "2-digit"
    }).format(now)
    if (!this.override) this.fieldTarget.value = this.localTimeValue(now)
  }

  render() {
    const adjusting = Boolean(this.override)
    this.clockTarget.hidden = adjusting
    this.adjustButtonTarget.hidden = adjusting
    this.fieldTarget.hidden = !adjusting
    this.resetButtonTarget.hidden = !adjusting
    this.fieldTarget.step = adjusting ? "300" : "60"
    if (adjusting) this.fieldTarget.value = this.override
    this.updateClock()
  }

  showAdjustment() {
    this.override = this.nearestFiveMinute(this.localTimeValue(new Date()))
    sessionStorage.setItem(this.storageKey, this.override)
    this.render()
    this.fieldTarget.focus()
  }

  change() {
    if (!this.fieldTarget.value) return this.useCurrentTime()
    if (!this.fieldTarget.reportValidity()) return

    this.override = this.fieldTarget.value
    sessionStorage.setItem(this.storageKey, this.override)
  }

  useCurrentTime() {
    this.override = null
    sessionStorage.removeItem(this.storageKey)
    this.render()
  }

  localTimeValue(date) {
    return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`
  }

  nearestFiveMinute(value) {
    const [hours, minutes] = value.split(":").map(Number)
    const time = new Date()
    time.setHours(hours, Math.round(minutes / 5) * 5, 0, 0)
    return this.localTimeValue(time)
  }

  submit(event) {
    const input = event.target.querySelector('input[name="checkin_time"], input[name="checkout_time"]')
    if (!input) return

    if (this.override) {
      this.change()
      if (this.override && !this.fieldTarget.reportValidity()) {
        event.preventDefault()
        return
      }
    }

    input.value = this.override || this.localTimeValue(new Date())
  }
}
