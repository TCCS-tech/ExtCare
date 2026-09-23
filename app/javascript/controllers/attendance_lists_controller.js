import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "ready", "completed", "item", "status" ]

  itemTargetConnected(item) {
    const destination = item.dataset.completed === "true" ? this.completedTarget : this.readyTarget
    if (item.parentElement === destination) return

    // Turbo replaces the row with the saved state; move that same row between lists.
    const before = item.getBoundingClientRect()
    destination.prepend(item)
    const after = item.getBoundingClientRect()

    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      item.animate([
        { transform: `translate(${before.left - after.left}px, ${before.top - after.top}px)`, backgroundColor: "#f8eaf0", zIndex: 2 },
        { transform: "translate(0, 0)", backgroundColor: "#ffffff", zIndex: 2 }
      ], { duration: 450, easing: "cubic-bezier(0.22, 1, 0.36, 1)" })
    }

    this.statusTarget.textContent = `${item.querySelector(".student-name").textContent}: ${item.dataset.attendanceStatus}.`
  }
}
