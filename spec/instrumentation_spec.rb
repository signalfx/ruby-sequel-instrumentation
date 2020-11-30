require 'spec_helper'

RSpec.describe Sequel::Instrumentation do
  let(:db) { Sequel.sqlite }
  let(:tracer) { OpenTracingTestTracer.build }
  let(:db_tags) { { 'component' => 'ruby-sequel', 'span.kind' => 'client', 'db.type' => 'sqlite' }.freeze } # rubocop:disable Metrics/LineLength

  before { described_class.instrument(tracer: tracer) }

  describe 'Class Methods' do
    it { is_expected.to respond_to :instrument }
    it { is_expected.to respond_to :trace_query }
  end

  describe 'trace query helper' do
    let(:name) { 'test_helper' }
    let(:tags) { db_tags.dup }

    before { tracer.spans.clear }

    it 'yields to the caller' do
      expect { |b| described_class.trace_query(name, tags, &b) }.to yield_with_no_args
    end

    it 'adds a span for yielded block' do
      described_class.trace_query(name, tags) do
        2.times { 10 * 10 } # some fake work
      end

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end
  end

  describe 'database queries' do
    before do
      db.drop_table? :items
      tracer.spans.clear
    end

    it 'adds a span for CREATE TABLE' do
      create_table(db, :items)

      tags = {
        'db.statement' => 'CREATE TABLE `items` ('\
          '`id` integer NOT NULL PRIMARY KEY AUTOINCREMENT, '\
          '`name` varchar(255) NOT NULL UNIQUE, '\
          '`price` double precision NOT NULL)',
      }.merge(db_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end

    it 'adds a span for DROP TABLE' do
      create_table(db, :items)
      db.run('select * from items')
      tracer.spans.clear

      db.drop_table? :items

      tags = {
        'db.statement' => 'DROP TABLE IF EXISTS `items`',
      }.merge(db_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end

    it 'adds a span for abitrary sql code' do
      create_table(db, :items)
      db[:items].all
      tracer.spans.clear

      statement = 'INSERT INTO items (name, price) VALUES (\'abc\', 100)'
      db.run(statement)

      tags = {
        'db.statement' => statement,
      }.merge(db_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end
  end

  describe 'ORM queries' do
    let(:dataset) { db[:items] }
    let(:dataset_tags) { { 'db.instance' => 'items' }.merge(db_tags).freeze }

    before do
      db.drop_table? :items
      create_table(db, :items)

      # perform query, because some drivers will do some extra queries for
      # caching on first request
      dataset.all

      tracer.spans.clear
    end

    it 'adds a span for all' do
      dataset.all

      tags = {
        'db.statement' => 'SELECT * FROM `items`',
      }.merge(dataset_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end

    it 'adds a span for insert' do
      dataset.insert(name: 'abc', price: 100)

      tags = {
        'db.statement' => 'INSERT INTO `items` (`name`, `price`) VALUES (\'abc\', 100)',
      }.merge(dataset_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end

    it 'adds a span for delete' do
      dataset.insert(name: 'abc', price: 100)
      tracer.spans.clear

      dataset.where(price: 100).delete

      tags = {
        'db.statement' => 'DELETE FROM `items` WHERE (`price` = 100)',
      }.merge(dataset_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end

    it 'adds a span for count' do
      dataset.count

      tags = {
        'db.statement' => 'SELECT count(*) AS \'count\' FROM `items` LIMIT 1',
      }.merge(dataset_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end

    it 'adds a span for avg' do
      dataset.avg(:price)

      tags = {
        'db.statement' => 'SELECT avg(`price`) AS \'avg\' FROM `items` LIMIT 1',
      }.merge(dataset_tags)

      expect(tracer.spans.count).to eq 1
      expect(tracer.spans.last.tags).to eq tags
    end

    it 'records error on span' do

      people_dataset = db[:people]
      error = nil
      begin
        puts people_dataset.count
      rescue StandardError => e
        error = e
      end

      expect(tracer.spans.count).to eq 1
      expected_tags = {
        "db.type" => "sqlite",
        "db.statement" => "SELECT count(*) AS 'count' FROM `people` LIMIT 1",
        "db.instance" => "people",
        "component" => "ruby-sequel",
        "span.kind" => "client",
        "error" => true,
        "sfx.error.kind" => "Sequel::DatabaseError",
        "sfx.error.message" => "SQLite3::SQLException: no such table: people",
        "sfx.error.stack": error.backtrace.join('\n')
      }
    end
  end
end
