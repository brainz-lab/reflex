# frozen_string_literal: true

puts "Seeding Reflex development data..."

# Create a development project
project = Project.find_or_create_by!(platform_project_id: "dev_seed_project") do |p|
  p.name = "Demo App"
end

puts "Created project: #{project.name}"

# Sample error data
errors_data = [
  {
    error_class: "NoMethodError",
    message: "undefined method `name' for nil:NilClass",
    file_path: "app/models/user.rb",
    line_number: 42,
    function_name: "full_name",
    status: "unresolved",
    events: 47,
    backtrace: [
      "app/models/user.rb:42:in `full_name'",
      "app/controllers/users_controller.rb:15:in `show'",
      "actionpack (7.1.0) lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action'",
      "actionpack (7.1.0) lib/abstract_controller/base.rb:201:in `process_action'"
    ]
  },
  {
    error_class: "ActiveRecord::RecordNotFound",
    message: "Couldn't find Order with 'id'=12345",
    file_path: "app/controllers/orders_controller.rb",
    line_number: 28,
    function_name: "show",
    status: "unresolved",
    events: 23,
    backtrace: [
      "app/controllers/orders_controller.rb:28:in `show'",
      "actionpack (7.1.0) lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action'",
      "actionpack (7.1.0) lib/abstract_controller/base.rb:201:in `process_action'"
    ]
  },
  {
    error_class: "Redis::CannotConnectError",
    message: "Error connecting to Redis on localhost:6379 (Errno::ECONNREFUSED)",
    file_path: "app/services/cache_service.rb",
    line_number: 15,
    function_name: "fetch",
    status: "resolved",
    events: 156,
    backtrace: [
      "app/services/cache_service.rb:15:in `fetch'",
      "app/models/product.rb:89:in `cached_price'",
      "app/controllers/products_controller.rb:12:in `index'"
    ]
  },
  {
    error_class: "ActionController::ParameterMissing",
    message: "param is missing or the value is empty: user",
    file_path: "app/controllers/users_controller.rb",
    line_number: 67,
    function_name: "user_params",
    status: "unresolved",
    events: 12,
    backtrace: [
      "app/controllers/users_controller.rb:67:in `user_params'",
      "app/controllers/users_controller.rb:23:in `create'",
      "actionpack (7.1.0) lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action'"
    ]
  },
  {
    error_class: "Stripe::CardError",
    message: "Your card was declined. Your request was in live mode, but used a known test card.",
    file_path: "app/services/payment_service.rb",
    line_number: 34,
    function_name: "charge",
    status: "ignored",
    events: 8,
    backtrace: [
      "app/services/payment_service.rb:34:in `charge'",
      "app/controllers/checkout_controller.rb:45:in `process_payment'",
      "app/controllers/checkout_controller.rb:12:in `create'"
    ]
  },
  {
    error_class: "Timeout::Error",
    message: "execution expired",
    file_path: "app/services/external_api_client.rb",
    line_number: 23,
    function_name: "fetch_data",
    status: "unresolved",
    events: 89,
    backtrace: [
      "app/services/external_api_client.rb:23:in `fetch_data'",
      "app/jobs/sync_inventory_job.rb:15:in `perform'",
      "activejob (7.1.0) lib/active_job/execution.rb:53:in `perform_now'"
    ]
  },
  {
    error_class: "JSON::ParserError",
    message: "unexpected token at '{invalid json'",
    file_path: "app/services/webhook_handler.rb",
    line_number: 18,
    function_name: "parse_payload",
    status: "resolved",
    events: 34,
    backtrace: [
      "app/services/webhook_handler.rb:18:in `parse_payload'",
      "app/controllers/webhooks_controller.rb:9:in `receive'",
      "actionpack (7.1.0) lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action'"
    ]
  },
  {
    error_class: "ArgumentError",
    message: "invalid date format: '2024-13-45'",
    file_path: "app/models/report.rb",
    line_number: 56,
    function_name: "parse_date_range",
    status: "unresolved",
    events: 5,
    backtrace: [
      "app/models/report.rb:56:in `parse_date_range'",
      "app/controllers/reports_controller.rb:34:in `generate'",
      "actionpack (7.1.0) lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action'"
    ]
  },
  {
    error_class: "Net::SMTPAuthenticationError",
    message: "535 5.7.8 Username and Password not accepted",
    file_path: "app/mailers/application_mailer.rb",
    line_number: 12,
    function_name: "deliver",
    status: "resolved",
    events: 203,
    backtrace: [
      "app/mailers/application_mailer.rb:12:in `deliver'",
      "app/mailers/user_mailer.rb:8:in `welcome_email'",
      "app/controllers/registrations_controller.rb:25:in `create'"
    ]
  },
  {
    error_class: "PG::UniqueViolation",
    message: "duplicate key value violates unique constraint \"users_email_key\"",
    file_path: "app/models/user.rb",
    line_number: 12,
    function_name: "save",
    status: "unresolved",
    events: 17,
    backtrace: [
      "app/models/user.rb:12:in `save'",
      "app/controllers/users_controller.rb:24:in `create'",
      "actionpack (7.1.0) lib/action_controller/metal/basic_implicit_render.rb:6:in `send_action'"
    ]
  }
]

request_methods = %w[GET POST PUT PATCH DELETE]
request_paths = [
  "/users", "/users/123", "/orders", "/orders/456/checkout",
  "/products", "/api/v1/sync", "/webhooks/stripe", "/reports/daily"
]
environments = %w[production staging]
users = [
  { id: "user_1", email: "alice@example.com" },
  { id: "user_2", email: "bob@example.com" },
  { id: "user_3", email: "charlie@example.com" },
  nil
]
commits = %w[a1b2c3d e4f5g6h i7j8k9l m0n1o2p q3r4s5t u6v7w8x]
branches = %w[main develop feature/checkout feature/user-auth hotfix/payment-bug]

# Breadcrumb templates - realistic user session flows
breadcrumb_flows = [
  # E-commerce checkout flow
  [
    { type: "navigation", category: "navigation", message: "Navigated to /", data: { from: nil, to: "/" }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /products", data: { from: "/", to: "/products" }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Add to Cart' button", data: { element: "button.add-to-cart", text: "Add to Cart" }, level: "info" },
    { type: "http", category: "http", message: "POST /cart/items", data: { method: "POST", url: "/cart/items", status_code: 200 }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /cart", data: { from: "/products", to: "/cart" }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Checkout' button", data: { element: "button.checkout", text: "Proceed to Checkout" }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /checkout", data: { from: "/cart", to: "/checkout" }, level: "info" },
    { type: "ui.input", category: "ui", message: "Filled shipping address form", data: { form: "shipping-form", fields: [ "address", "city", "zip" ] }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Continue to Payment' button", data: { element: "button.continue", text: "Continue to Payment" }, level: "info" },
    { type: "http", category: "http", message: "POST /checkout/payment", data: { method: "POST", url: "/checkout/payment", status_code: 500 }, level: "error" }
  ],
  # User registration flow
  [
    { type: "navigation", category: "navigation", message: "Navigated to /", data: { from: nil, to: "/" }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Sign Up' link", data: { element: "a.signup", text: "Sign Up" }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /signup", data: { from: "/", to: "/signup" }, level: "info" },
    { type: "ui.input", category: "ui", message: "Filled email field", data: { field: "email", value: "j***@example.com" }, level: "info" },
    { type: "ui.input", category: "ui", message: "Filled password field", data: { field: "password", value: "********" }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Create Account' button", data: { element: "button.submit", text: "Create Account" }, level: "info" },
    { type: "http", category: "http", message: "POST /users", data: { method: "POST", url: "/users", status_code: 422 }, level: "warning" }
  ],
  # Dashboard analytics flow
  [
    { type: "navigation", category: "navigation", message: "Navigated to /login", data: { from: nil, to: "/login" }, level: "info" },
    { type: "ui.input", category: "ui", message: "Filled login form", data: { form: "login-form", fields: [ "email", "password" ] }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Sign In' button", data: { element: "button.login", text: "Sign In" }, level: "info" },
    { type: "http", category: "http", message: "POST /sessions", data: { method: "POST", url: "/sessions", status_code: 200 }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /dashboard", data: { from: "/login", to: "/dashboard" }, level: "info" },
    { type: "http", category: "http", message: "GET /api/v1/analytics", data: { method: "GET", url: "/api/v1/analytics", status_code: 200 }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Reports' tab", data: { element: "a.reports-tab", text: "Reports" }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /dashboard/reports", data: { from: "/dashboard", to: "/dashboard/reports" }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked 'Generate Report' button", data: { element: "button.generate", text: "Generate Report" }, level: "info" },
    { type: "console", category: "console", message: "Starting report generation...", data: { logger: "ReportService" }, level: "debug" },
    { type: "http", category: "http", message: "POST /api/v1/reports", data: { method: "POST", url: "/api/v1/reports", status_code: 500 }, level: "error" }
  ],
  # Order management flow
  [
    { type: "navigation", category: "navigation", message: "Navigated to /admin", data: { from: nil, to: "/admin" }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /admin/orders", data: { from: "/admin", to: "/admin/orders" }, level: "info" },
    { type: "http", category: "http", message: "GET /api/v1/orders", data: { method: "GET", url: "/api/v1/orders", status_code: 200 }, level: "info" },
    { type: "ui.click", category: "ui", message: "Clicked order row #12345", data: { element: "tr.order-row", order_id: "12345" }, level: "info" },
    { type: "navigation", category: "navigation", message: "Navigated to /admin/orders/12345", data: { from: "/admin/orders", to: "/admin/orders/12345" }, level: "info" },
    { type: "http", category: "http", message: "GET /api/v1/orders/12345", data: { method: "GET", url: "/api/v1/orders/12345", status_code: 404 }, level: "error" }
  ],
  # API integration flow
  [
    { type: "console", category: "console", message: "Starting sync job", data: { job: "SyncInventoryJob", queue: "default" }, level: "info" },
    { type: "http", category: "http", message: "GET /api/external/inventory", data: { method: "GET", url: "https://api.supplier.com/inventory", status_code: 200 }, level: "info" },
    { type: "console", category: "console", message: "Fetched 1,234 inventory items", data: { count: 1234 }, level: "info" },
    { type: "console", category: "console", message: "Processing batch 1/13", data: { batch: 1, total: 13 }, level: "debug" },
    { type: "http", category: "http", message: "POST /api/v1/inventory/bulk", data: { method: "POST", url: "/api/v1/inventory/bulk", status_code: 200 }, level: "info" },
    { type: "console", category: "console", message: "Processing batch 2/13", data: { batch: 2, total: 13 }, level: "debug" },
    { type: "http", category: "http", message: "POST /api/v1/inventory/bulk", data: { method: "POST", url: "/api/v1/inventory/bulk" }, level: "info" },
    { type: "console", category: "console", message: "Connection timeout waiting for response", data: { timeout: 30000 }, level: "error" }
  ]
]

def generate_breadcrumbs(base_time, flow)
  flow.each_with_index.map do |crumb, i|
    crumb.merge(timestamp: (base_time - (flow.length - i).minutes).iso8601)
  end
end

errors_data.each do |error_data|
  # Generate fingerprint
  fingerprint = FingerprintGenerator.generate(
    error_class: error_data[:error_class],
    message: error_data[:message],
    backtrace: error_data[:backtrace]
  )

  # Create error group
  first_seen = rand(7..30).days.ago
  last_seen = rand(1..120).minutes.ago

  group = ErrorGroup.find_or_create_by!(project: project, fingerprint: fingerprint) do |g|
    g.error_class = error_data[:error_class]
    g.message = error_data[:message]
    g.file_path = error_data[:file_path]
    g.line_number = error_data[:line_number]
    g.function_name = error_data[:function_name]
    g.status = error_data[:status]
    g.event_count = error_data[:events]
    g.first_seen_at = first_seen
    g.last_seen_at = last_seen
    g.last_commit = commits.sample
    g.last_environment = environments.sample
  end

  # Create events for this group
  event_count = [ error_data[:events], 10 ].min # Cap at 10 events per group for seeds

  event_count.times do |i|
    occurred_at = rand(first_seen..last_seen)
    user = users.sample
    commit = commits.sample

    # Use a unique key to avoid duplicates
    event = ErrorEvent.find_or_initialize_by(
      error_group: group,
      request_id: SecureRandom.uuid
    )

    next unless event.new_record?

    # Generate realistic breadcrumbs for this event
    flow = breadcrumb_flows.sample
    breadcrumbs = generate_breadcrumbs(occurred_at, flow)

    event.assign_attributes(
      project: project,
      error_class: error_data[:error_class],
      message: error_data[:message],
      environment: environments.sample,
      backtrace: error_data[:backtrace],
      request_method: request_methods.sample,
      request_path: request_paths.sample,
      request_params: { "id" => rand(1..1000).to_s },
      request_headers: {
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "Accept" => "text/html,application/json"
      },
      user_id: user&.dig(:id),
      user_email: user&.dig(:email),
      user_data: user || {},
      context: {
        "feature_flags" => { "new_checkout" => true },
        "ab_test" => "variant_b"
      },
      tags: { "team" => %w[backend frontend payments].sample },
      server_name: "web-#{rand(1..4)}.prod",
      release: "v1.#{rand(0..9)}.#{rand(0..20)}",
      commit: commit,
      branch: branches.sample,
      occurred_at: occurred_at,
      breadcrumbs: breadcrumbs
    )

    event.save!
  end

  puts "  Created error: #{error_data[:error_class]} (#{error_data[:status]}) - #{group.events.count} events"
end

# Update counters to match actual event counts
ErrorGroup.find_each do |group|
  group.update_columns(event_count: group.events.count)
end

puts "\nSeeding complete!"
puts "  Projects: #{Project.count}"
puts "  Error groups: #{ErrorGroup.count}"
puts "  Error events: #{ErrorEvent.count}"
puts "  Unresolved: #{ErrorGroup.unresolved.count}"
puts "  Resolved: #{ErrorGroup.resolved.count}"
puts "  Ignored: #{ErrorGroup.ignored.count}"
