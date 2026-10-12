# frozen_string_literal: true

module InertiaRails
  # Turns the names in the body of an Inertia request back into the ones the application declared,
  # for `camelize_props`.
  #
  # A name that is not one `CamelCase` could have produced is dropped rather than renamed, so the
  # application is reached under one name only. What a missing parameter costs is the action's to
  # say, as it is for one the client never sent: `params.expect` answers 400.
  #
  # The query string and the path parameters are left alone. The client writes the query string
  # into the address bar, and the same URL comes back from a bookmark without `X-Inertia`, so its
  # names have to work without any renaming. Path parameters are named by the routes.
  module CamelCaseParameters
    class << self
      def rename!(request)
        request.request_parameters = rename_keys(request.request_parameters)
        # `parameters` merges the body with the query string and the path parameters once and keeps
        # the result, which still holds the names the body arrived with.
        request.delete_header('action_dispatch.request.parameters')
      end

      private

      # Built as the same class, since Rails parses the body into a `HashWithIndifferentAccess` and
      # `ParamsWrapper` looks its key up as a Symbol.
      def rename_keys(hash)
        hash.each_with_object(hash.class.new) do |(name, value), renamed|
          if CamelCase.key(name.to_s) == name.to_s
            renamed[name.to_s.underscore] = rename_value(value)
          else
            Rails.logger&.warn("[inertia-rails] camelize_props dropped the parameter #{name}, which is not camelCase")
          end
        end
      end

      def rename_value(value)
        case value
        when Hash then rename_keys(value)
        when Array then value.map { |item| rename_value(item) }
        else value
        end
      end
    end
  end
end
