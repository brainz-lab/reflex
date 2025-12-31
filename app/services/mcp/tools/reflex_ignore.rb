module Mcp
  module Tools
    class ReflexIgnore < Base
      DESCRIPTION = "Ignore an error. It won't appear in the unresolved list."

      SCHEMA = {
        type: "object",
        properties: {
          error_id: { type: "string", description: "Error group ID" }
        },
        required: [ "error_id" ]
      }.freeze

      def call(args)
        error = @project.error_groups.find(args[:error_id])
        error.ignore!

        { ignored: true, error_id: error.id, error_class: error.error_class }
      rescue ActiveRecord::RecordNotFound
        { error: "Error not found" }
      end
    end
  end
end
