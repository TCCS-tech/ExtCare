import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String, step: String }
  static targets = ["confirmation", "submit", "status"]

  connect() {
    this.confirm()
    if (["waiting", "download"].includes(this.stepValue)) {
      this.interval = window.setInterval(() => this.check(), 2000)
      this.check()
    }
  }

  disconnect() {
    window.clearInterval(this.interval)
    this.request?.abort()
  }

  confirm() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = this.confirmationTarget.value !== "I UNDERSTAND"
  }

  async check() {
    if (this.request || document.hidden) return
    const request = new AbortController()
    this.request = request
    const timeout = window.setTimeout(() => request.abort(), 10000)
    try {
      const response = await fetch(this.urlValue, {
        cache: "no-store", headers: { Accept: "application/json" }, signal: request.signal
      })
      if (!response.ok || response.redirected) throw new Error("Status unavailable")
      const { step } = await response.json()
      this.statusTarget.textContent = ""
      if (step !== this.stepValue) Turbo.visit(window.location.href, { action: "replace" })
    } catch {
      if (this.element.isConnected) this.statusTarget.textContent = "Connection interrupted. We'll keep checking automatically."
    } finally {
      window.clearTimeout(timeout)
      this.request = null
    }
  }
}
