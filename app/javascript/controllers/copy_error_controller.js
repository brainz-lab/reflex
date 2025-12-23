import { Controller } from "@hotwired/stimulus"

// Copies error details to clipboard formatted for AI debugging
export default class extends Controller {
  static values = {
    errorClass: String,
    message: String,
    location: String,
    backtrace: Array,
    requestMethod: String,
    requestPath: String,
    params: Object,
    context: Object,
    environment: String,
    commit: String
  }

  copy() {
    const text = this.formatForAI()

    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback("Copied!")
    }).catch(() => {
      this.showFeedback("Failed to copy")
    })
  }

  formatForAI() {
    const parts = []

    parts.push("## Error to Debug\n")
    parts.push(`**Error Class:** ${this.errorClassValue}`)
    parts.push(`**Message:** ${this.messageValue}`)

    if (this.locationValue) {
      parts.push(`**Location:** ${this.locationValue}`)
    }

    if (this.backtraceValue && this.backtraceValue.length > 0) {
      parts.push("\n### Backtrace")
      parts.push("```")
      this.backtraceValue.forEach(frame => {
        const line = frame.line ? `:${frame.line}` : ''
        const func = frame.function ? ` in ${frame.function}` : ''
        parts.push(`${frame.file}${line}${func}`)
      })
      parts.push("```")
    }

    if (this.requestMethodValue || this.requestPathValue) {
      parts.push("\n### Request")
      if (this.requestMethodValue) parts.push(`- Method: ${this.requestMethodValue}`)
      if (this.requestPathValue) parts.push(`- Path: ${this.requestPathValue}`)
    }

    if (this.paramsValue && Object.keys(this.paramsValue).length > 0) {
      parts.push("\n### Params")
      parts.push("```json")
      parts.push(JSON.stringify(this.paramsValue, null, 2))
      parts.push("```")
    }

    if (this.contextValue && Object.keys(this.contextValue).length > 0) {
      parts.push("\n### Context")
      parts.push("```json")
      parts.push(JSON.stringify(this.contextValue, null, 2))
      parts.push("```")
    }

    parts.push("\n### Environment")
    if (this.environmentValue) parts.push(`- Environment: ${this.environmentValue}`)
    if (this.commitValue) parts.push(`- Commit: ${this.commitValue}`)

    parts.push("\n---")
    parts.push("Please help me debug and fix this error.")

    return parts.join("\n")
  }

  showFeedback(message) {
    const button = this.element.querySelector('button') || this.element
    const originalText = button.innerHTML

    button.innerHTML = `
      <svg width="14" height="14" viewBox="0 0 16 16" fill="none" class="inline-block mr-1">
        <path d="M13.5 4.5L6 12L2.5 8.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      ${message}
    `

    setTimeout(() => {
      button.innerHTML = originalText
    }, 2000)
  }
}
