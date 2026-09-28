import { Controller } from "@hotwired/stimulus"

// Keep the version of the loaded document, even after Turbo navigations.
const loadedVersion = document.querySelector('meta[name="build-version"]').content

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.interval = window.setInterval(() => this.check(), 60_000)
    this.check()
  }

  disconnect() {
    window.clearInterval(this.interval)
    this.request?.abort()
  }

  async check() {
    if (document.hidden || this.request || !this.element.hidden) return

    const request = new AbortController()
    this.request = request
    const timeout = window.setTimeout(() => request.abort(), 10_000)

    try {
      const response = await fetch(this.urlValue, {
        cache: "no-store",
        headers: { Accept: "application/json" },
        signal: request.signal
      })
      if (!response.ok) return

      const { version } = await response.json()
      if (typeof version === "string" && version && version !== loadedVersion) {
        this.element.hidden = false
      }
    } catch {
      // Offline, deployment downtime, and timeouts can wait for the next check.
    } finally {
      window.clearTimeout(timeout)
      this.request = null
    }
  }

  reload() {
    window.location.reload()
  }
}
