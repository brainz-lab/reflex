import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["container", "toggle"]
  static values = { projectId: String }

  connect() {
    this.consumer = createConsumer()
  }

  toggle(event) {
    event.target.checked ? this.start() : this.stop()
  }

  start() {
    this.subscription = this.consumer.subscriptions.create(
      { channel: "ErrorsChannel", project_id: this.projectIdValue },
      {
        received: (data) => {
          if (data.type === 'new_error') {
            this.prependError(data)
          }
        }
      }
    )
  }

  stop() {
    this.subscription?.unsubscribe()
  }

  prependError(data) {
    const error = data.error_group
    const html = `
      <a href="/dashboard/projects/${this.projectIdValue}/errors/${error.id}" class="block hover:bg-red-50 transition border-b border-stone-100 bg-red-50/50">
        <div class="flex items-start gap-4 p-4">
          <div class="mt-1">
            <span class="w-2 h-2 rounded-full bg-red-500 block animate-pulse"></span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="font-medium text-red-600">${this.escapeHtml(error.error_class)}</span>
              <span class="text-xs bg-red-100 text-red-600 px-1.5 py-0.5 rounded">NEW</span>
            </div>
            <p class="text-stone-600 truncate mt-1">${this.escapeHtml(error.message || '')}</p>
            <div class="flex items-center gap-4 mt-2 text-xs text-stone-400">
              <span>${error.event_count} events</span>
              <span>Just now</span>
            </div>
          </div>
        </div>
      </a>
    `
    this.containerTarget.insertAdjacentHTML('afterbegin', html)
  }

  escapeHtml(text) {
    if (!text) return ''
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  disconnect() {
    this.stop()
    this.consumer?.disconnect()
  }
}
