require 'sqlite3'
require 'forwardable'
require 'cnbanks/connection_pool'
module CNBanks
  class Database

    extend Forwardable

    DEFAULT_DBFILE  = 'cnbanks.db'.freeze

    def self.establish_connection(options = {}, &block)
      new(options, &block)
    end

    def_delegator :connection_pool, :with_connection

    def initialize(options = {}, &block)
      @file      = options.fetch(:file, DEFAULT_DBFILE)
      @pool_size = options.fetch(:pool, 5)
      @timeout   = options.fetch(:timeout, 5)
      @lock      = Mutex.new
      yield self if block_given?
    end

    # Execute SQL statement.
    #
    def execute(sql, *bind_vars, &block)
      sync { with_connection { |conn| conn.execute sql, *bind_vars, &block } }
    end

    def execute_batch(sql, *bind_vars, &block)
      sync { with_connection { |conn| conn.execute_batch sql, *bind_vars, &block } }
    end

    # Close database
    #
    def shutdown(&block)
      connection_pool.shutdown(&block)
    end
    alias_method :close, :shutdown

    private

      def connection_pool
        @connection_pool ||= ConnectionPool.new(size: @pool_size, timeout: @timeout) { SQLite3::Database.new(@file) }
      end

      def sync(&block)
        @lock.synchronize { yield }
      end

  end # Database
end # ProxyPump
