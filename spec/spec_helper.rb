require 'bundler/setup'
require 'sequel/instrumentation'
require 'signalfx_test_tracer'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def create_table(db, table)
  db.create_table table do
    primary_key :id
    String :name, unique: true, null: false
    Float :price, null: false
  end
end
