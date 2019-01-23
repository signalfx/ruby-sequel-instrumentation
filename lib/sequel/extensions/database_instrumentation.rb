require 'opentracing'

module Sequel
  module TraceDatabase
    OPTS = {}.freeze unless defined? ::Sequel::Dataset::OPTS

    def execute_ddl(sql, opts = OPTS, &block)
      tags = {
        'db.type' => database_type.to_s,
        'db.statement' => sql,
      }

      ::Sequel::Instrumentation.trace_query('sequel.database.execute', tags) do
        super
      end
    end
  end

  Sequel::Database.register_extension(:database_instrumentation, TraceDatabase)
end
