import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "list" ]
  static values = { reorderUrl: String }

  dragStart(event) {
    this.draggedCard = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedCard.dataset.taskId)
    requestAnimationFrame(() => this.draggedCard?.classList.add("is-dragging"))
  }

  dragOver(event) {
    event.preventDefault()
    const list = event.currentTarget
    const after = this.cardAfterPointer(list, event.clientY)
    const dragged = this.draggedCard || document.querySelector(".task-card.is-dragging")
    if (!dragged) return
    if (after) list.insertBefore(dragged, after)
    else list.append(dragged)
    list.querySelector(".task-empty")?.remove()
  }

  async drop(event) {
    event.preventDefault()
    const list = event.currentTarget
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token, "Accept": "application/json" },
      body: JSON.stringify({ status: list.dataset.status, task_ids: Array.from(list.querySelectorAll(".task-card"), card => card.dataset.taskId) })
    })
    if (!response.ok) window.location.reload()
  }

  dragEnd() {
    this.draggedCard?.classList.remove("is-dragging")
    this.draggedCard = null
  }

  cardAfterPointer(list, y) {
    return Array.from(list.querySelectorAll(".task-card:not(.is-dragging)")).reduce((closest, card) => {
      const box = card.getBoundingClientRect()
      const offset = y - box.top - box.height / 2
      return offset < 0 && offset > closest.offset ? { offset, element: card } : closest
    }, { offset: Number.NEGATIVE_INFINITY, element: null }).element
  }
}
