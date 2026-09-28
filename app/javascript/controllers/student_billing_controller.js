import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "section", "date", "prepaidAm", "prepaidPm"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasSectionTarget) return

    const changed = this.categoryTargets.some(input => input.checked !== (input.dataset.original === "true"))
    this.sectionTarget.hidden = !changed
    this.dateTarget.disabled = !changed
    if (!changed) this.dateTarget.value = ""
  }

  syncPrepaidPm() {
    if (this.prepaidAmTarget.checked) this.prepaidPmTarget.checked = true
    this.toggle()
  }
}
