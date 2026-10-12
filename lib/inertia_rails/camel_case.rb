# frozen_string_literal: true

module InertiaRails
  # The names `camelize_props` gives the client. Every conversion goes through one name at a time,
  # so a prop key, a path in the page metadata and a flash key all come out the same way.
  module CamelCase
    class << self
      # Keeps a Symbol a Symbol, so that a key looked up by symbol still matches once converted.
      # Keys that are not names, such as integers, are left alone.
      def key(name)
        return name unless name.is_a?(String) || name.is_a?(Symbol)

        camelized = camelize(name.to_s)
        name.is_a?(Symbol) ? camelized.to_sym : camelized
      end

      # Each segment of a dot path is a name of its own; array indices convert to themselves.
      def path(path)
        path.to_s.split('.').map { |segment| camelize(segment) }.join('.')
      end

      def deep(value)
        case value
        when Hash then value.each_with_object({}) { |(name, nested), result| result[key(name)] = deep(nested) }
        when Array then value.map { |item| deep(item) }
        else value
        end
      end

      private

      # `camelize` drops leading underscores and capitalizes what follows (`_destroy` becomes
      # `Destroy`), which `underscore` cannot turn back. Keeping them lets `_record_id` go out as
      # `_recordId` and come back as `_record_id`.
      def camelize(name)
        prefix = name[/\A_*/]
        prefix + name.delete_prefix(prefix).camelize(:lower)
      end
    end
  end
end
