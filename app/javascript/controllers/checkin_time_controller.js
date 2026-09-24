import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

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
