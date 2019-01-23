require 'sequel/instrumentation/version'

require 'opentracing'

module Sequel
  module Instrumentation
    class Error < StandardError; end

    class << self
      COMMON_TAGS = {
        'component' => 'ruby-sequel',
        'span.kind' => 'client',
      }.freeze

      attr_accessor :tracer

      def instrument(tracer: OpenTracing.global_tracer)
        begin
          require 'sequel'
        rescue LoadError
          return
        end

        @tracer = tracer

        require 'sequel/extensions/database_instrumentation'
        require 'sequel/extensions/dataset_instrumentation'

        Sequel::Database.extension :database_instrumentation
        Sequel::Database.extension :dataset_instrumentation
      end

      # This method sets up a span and yields the block.
      # Any errors will be caught and tagged before being passed up.
      def trace_query(name, tags)
        tags.merge!(COMMON_TAGS)

        scope = @tracer.start_active_span(name, tags: tags)

        yield
      rescue StandardError => error
        if scope
          scope.span.set_tag('error', true)
          scope.span.log_kv(key: 'message', value: error.message)
        end

        raise error
      ensure
        scope.close if scope
      end
    end
  end
end
