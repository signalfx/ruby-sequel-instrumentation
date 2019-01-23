require 'opentracing'

module Sequel
  module TracingDataset
    # datasets are included, not extended

    OPTS = {}.freeze unless defined? ::Sequel::Dataset::OPTS

    def execute(sql, opts = OPTS, &block)
      tags = populate_tracing_tags(sql)

      ::Sequel::Instrumentation.trace_query('sequel.dataset.execute', tags) do
        super
      end
    end

    def execute_dui(sql, opts = OPTS, &block)
      tags = populate_tracing_tags(sql)

      ::Sequel::Instrumentation.trace_query('sequel.dataset.execute', tags) do
        super
      end
    end

    def execute_insert(sql, opts = OPTS, &block)
      tags = populate_tracing_tags(sql)

      ::Sequel::Instrumentation.trace_query('sequel.dataset.execute_insert', tags) do
        super
      end
    end

    def populate_tracing_tags(sql)
      tags = {
        'db.type' => @db.database_type.to_s,
        'db.statement' => sql,
      }
      tags['db.instance'] = @opts[:from].first.to_s if @opts[:from] && !@opts[:from].empty?

      tags
    end
  end

  Sequel::Dataset.register_extension(:dataset_instrumentation, TracingDataset)
end
