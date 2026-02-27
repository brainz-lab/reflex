# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorProcessor, type: :service do
  describe "#process!" do
    it "creates error group and event" do
      project = create(:project)
      payload = sample_error_payload

      expect {
        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:error_group]).to be_present
        expect(result[:event]).to be_present
      }.to change(ErrorGroup, :count).by(1)
        .and change(ErrorEvent, :count).by(1)
    end

    it "finds existing error group by fingerprint" do
      project = create(:project)
      payload = sample_error_payload

      processor1 = ErrorProcessor.new(project: project, payload: payload)
      result1 = processor1.process!

      expect {
        processor2 = ErrorProcessor.new(project: project, payload: payload)
        result2 = processor2.process!

        expect(result2[:error_group].id).to eq(result1[:error_group].id)
      }.to change(ErrorGroup, :count).by(0)
        .and change(ErrorEvent, :count).by(1)
    end

    it "updates error group occurrence stats" do
      project = create(:project)
      error_group = create(:error_group,
        project: project,
        event_count: 5,
        last_seen_at: 2.hours.ago,
        last_commit: "old_commit"
      )

      allow(FingerprintGenerator).to receive(:generate).and_return(error_group.fingerprint)

      payload = sample_error_payload(commit: "new_commit")
      processor = ErrorProcessor.new(project: project, payload: payload)
      processor.process!

      error_group.reload
      expect(error_group.event_count).to eq(6)
      expect(error_group.last_seen_at.to_i).to be_within(1).of(Time.current.to_i)
      expect(error_group.last_commit).to eq("new_commit")
    end

    it "unresolves resolved error on new occurrence" do
      project = create(:project)
      error_group = create(:error_group,
        project: project,
        status: "resolved",
        resolved_at: 1.hour.ago
      )

      allow(FingerprintGenerator).to receive(:generate).and_return(error_group.fingerprint)

      payload = sample_error_payload
      processor = ErrorProcessor.new(project: project, payload: payload)
      processor.process!

      error_group.reload
      expect(error_group.status).to eq("unresolved")
      expect(error_group.resolved_at).to be_nil
    end

    context "error class extraction" do
      it "extracts error class from payload" do
        project = create(:project)
        payload = sample_error_payload(error_class: "CustomError")

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:error_group].error_class).to eq("CustomError")
        expect(result[:event].error_class).to eq("CustomError")
      end

      it "extracts error class from exception hash" do
        project = create(:project)
        payload = {
          exception: { class: "CustomError", message: "Something went wrong" },
          backtrace: ["app/models/user.rb:42:in `method'"]
        }

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:error_group].error_class).to eq("CustomError")
      end

      it "defaults to UnknownError if no error class provided" do
        project = create(:project)
        payload = {
          message: "Something went wrong",
          backtrace: ["app/models/user.rb:42:in `method'"]
        }

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:error_group].error_class).to eq("UnknownError")
      end
    end

    context "backtrace normalization" do
      it "normalizes string backtrace to hash format" do
        project = create(:project)
        payload = sample_error_payload(
          backtrace: [
            "app/models/user.rb:42:in `full_name'",
            "app/controllers/users_controller.rb:23:in `show'"
          ]
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        backtrace = result[:event].backtrace
        expect(backtrace.length).to eq(2)
        expect(backtrace[0]["file"]).to eq("app/models/user.rb")
        expect(backtrace[0]["line"]).to eq(42)
        expect(backtrace[0]["function"]).to eq("full_name")
        expect(backtrace[0]["in_app"]).to be true
      end

      it "marks gem frames as not in_app" do
        project = create(:project)
        payload = sample_error_payload(
          backtrace: [
            "app/models/user.rb:42:in `full_name'",
            "/gems/activerecord/lib/active_record.rb:100:in `save'"
          ]
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        backtrace = result[:event].backtrace
        expect(backtrace[0]["in_app"]).to be true
        expect(backtrace[1]["in_app"]).to be false
      end
    end

    context "parameter sanitization" do
      it "sanitizes sensitive parameters" do
        project = create(:project)
        payload = sample_error_payload(
          request: {
            params: {
              name: "John",
              password: "secret123",
              password_confirmation: "secret123",
              token: "api_token_123"
            }
          }
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        params = result[:event].request_params
        expect(params["name"]).to eq("John")
        expect(params["password"]).to eq("[FILTERED]")
        expect(params["password_confirmation"]).to eq("[FILTERED]")
        expect(params["token"]).to eq("[FILTERED]")
      end

      it "sanitizes nested sensitive parameters" do
        project = create(:project)
        payload = sample_error_payload(
          request: {
            params: {
              user: { name: "John", password: "secret123" }
            }
          }
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        params = result[:event].request_params
        expect(params["user"]["name"]).to eq("John")
        expect(params["user"]["password"]).to eq("[FILTERED]")
      end
    end

    context "timestamp parsing" do
      it "parses timestamp from string" do
        project = create(:project)
        timestamp_str = "2024-12-21T10:00:00Z"
        payload = sample_error_payload(timestamp: timestamp_str)

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:event].occurred_at.to_i).to eq(Time.parse(timestamp_str).to_i)
      end

      it "parses timestamp from numeric" do
        project = create(:project)
        timestamp_num = Time.current.to_i
        payload = sample_error_payload(timestamp: timestamp_num)

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:event].occurred_at.to_i).to eq(timestamp_num)
      end

      it "defaults to current time if timestamp invalid" do
        project = create(:project)
        payload = sample_error_payload(timestamp: "invalid")

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:event].occurred_at.to_i).to be_within(1).of(Time.current.to_i)
      end
    end

    context "backtrace extraction" do
      it "extracts file path from backtrace" do
        project = create(:project)
        payload = sample_error_payload(
          backtrace: ["app/models/user.rb:42:in `full_name'"]
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:error_group].file_path).to eq("app/models/user.rb")
      end

      it "extracts line number from backtrace" do
        project = create(:project)
        payload = sample_error_payload(
          backtrace: ["app/models/user.rb:42:in `full_name'"]
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:error_group].line_number).to eq(42)
      end

      it "extracts function name from backtrace" do
        project = create(:project)
        payload = sample_error_payload(
          backtrace: ["app/models/user.rb:42:in `full_name'"]
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        expect(result[:error_group].function_name).to eq("full_name")
      end
    end

    context "context storage" do
      it "stores request context in event" do
        project = create(:project)
        payload = sample_error_payload(
          request: {
            id: "req_123",
            method: "POST",
            url: "https://example.com/users",
            path: "/users",
            params: { name: "John" },
            headers: { "User-Agent" => "Mozilla" }
          }
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        event = result[:event]
        expect(event.request_id).to eq("req_123")
        expect(event.request_method).to eq("POST")
        expect(event.request_url).to eq("https://example.com/users")
        expect(event.request_path).to eq("/users")
        expect(event.request_params["name"]).to eq("John")
        expect(event.request_headers["User-Agent"]).to eq("Mozilla")
      end

      it "stores user context in event" do
        project = create(:project)
        payload = sample_error_payload(
          user: { id: "user_123", email: "john@example.com", name: "John Doe" }
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        event = result[:event]
        expect(event.user_id).to eq("user_123")
        expect(event.user_email).to eq("john@example.com")
        expect(event.user_data["name"]).to eq("John Doe")
      end

      it "stores environment metadata in event" do
        project = create(:project)
        payload = sample_error_payload(
          environment: "staging",
          commit: "abc123",
          branch: "main",
          release: "v1.2.3",
          server_name: "web-1"
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        event = result[:event]
        expect(event.environment).to eq("staging")
        expect(event.commit).to eq("abc123")
        expect(event.branch).to eq("main")
        expect(event.release).to eq("v1.2.3")
        expect(event.server_name).to eq("web-1")
      end

      it "stores custom context, tags, and extra data" do
        project = create(:project)
        payload = sample_error_payload(
          context: { custom: "value" },
          tags: { team: "backend" },
          extra: { debug_info: "test" },
          breadcrumbs: [{ action: "user.login" }]
        )

        processor = ErrorProcessor.new(project: project, payload: payload)
        result = processor.process!

        event = result[:event]
        expect(event.context["custom"]).to eq("value")
        expect(event.tags["team"]).to eq("backend")
        expect(event.extra["debug_info"]).to eq("test")
        expect(event.breadcrumbs[0]["action"]).to eq("user.login")
      end
    end

    it "handles empty request params" do
      project = create(:project)
      payload = sample_error_payload(request: { params: nil })

      processor = ErrorProcessor.new(project: project, payload: payload)
      result = processor.process!

      expect(result[:event].request_params).to eq({})
    end

    it "deep symbolizes keys in payload" do
      project = create(:project)
      payload = {
        "error_class" => "NoMethodError",
        "message" => "Test",
        "backtrace" => ["app/models/user.rb:42:in `method'"],
        "request" => {
          "method" => "POST",
          "params" => { "name" => "John" }
        }
      }

      processor = ErrorProcessor.new(project: project, payload: payload)
      result = processor.process!

      expect(result[:event]).to be_present
      expect(result[:event].error_class).to eq("NoMethodError")
    end
  end
end
