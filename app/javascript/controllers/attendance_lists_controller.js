import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "ready", "completed", "item", "status" ]

  initialize() {
    this.transitions = new Map()
  }

  async itemTargetConnected(item) {
    const destination = item.dataset.completed === "true" ? this.completedTarget : this.readyTarget
    if (item.parentElement === destination || this.transitions.has(item)) return

    // Only animate the saved row returned by Turbo, never an unconfirmed action.
    this.statusTarget.textContent = `${item.querySelector(".student-name").textContent}: ${item.dataset.attendanceStatus}.`
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.insertInOrder(destination, item)
      return
    }

    const transition = { destination }
    this.transitions.set(item, transition)
    const height = item.getBoundingClientRect().height
    transition.animation = item.animate([
      { maxHeight: `${height}px`, opacity: 1, transform: "scale(1)", overflow: "hidden" },
      { maxHeight: `${height}px`, opacity: 0.3, transform: "scale(0.96)", overflow: "hidden", offset: 0.45 },
      { maxHeight: "0px", opacity: 0, transform: "scale(0.96)", paddingTop: "0px", paddingBottom: "0px", borderTopWidth: "0px", borderBottomWidth: "0px", overflow: "hidden" }
    ], { duration: 480, easing: "ease-in-out", fill: "forwards" })

    await transition.animation.finished.catch(() => {})
    if (this.transitions.get(item) !== transition) return

    this.insertInOrder(destination, item)
    transition.animation.cancel()
    transition.animation = item.animate([
      { opacity: 0, transform: "scale(0.97)", backgroundColor: "#f8eaf0" },
      { opacity: 1, transform: "scale(1)", backgroundColor: "#ffffff" }
    ], { duration: 320, easing: "ease-out" })
    await transition.animation.finished.catch(() => {})
    this.transitions.delete(item)
  }

  insertInOrder(destination, item) {
    const next = Array.from(destination.children).find(other => {
      if (other === item) return false
      const firstName = item.dataset.firstName.localeCompare(other.dataset.firstName, "en")
      const lastName = item.dataset.lastName.localeCompare(other.dataset.lastName, "en")
      return (firstName || lastName || Number(item.dataset.studentId) - Number(other.dataset.studentId)) < 0
    })
    destination.insertBefore(item, next || null)
  }

  finishTransitions() {
    for (const [item, transition] of this.transitions) {
      this.insertInOrder(transition.destination, item)
      transition.animation.cancel()
    }
    this.transitions.clear()
  }

  disconnect() {
    this.finishTransitions()
  }
}
