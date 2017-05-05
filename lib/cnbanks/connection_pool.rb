module CNBanks
  class ConnectionPool

    class Error < StandardError           ; end
    class TimeoutError < Error            ; end
    class ConnectionNotFoundError < Error ; end
    class PoolShuttingdownError < Error   ; end

    def initialize(options = {}, &block)
      raise ArgumentError, 'ConnectionPool must receive a block to create connection.' unless block_given?
      @max_size  = options.fetch(:size, 5)
      @timeout   = options.fetch(:timeout, 5)
      @idle      = Hash.new
      @busy      = Hash.new
      @lock      = Mutex.new
      @available  = ConditionVariable.new
      @create_proc = block
    end

    # Obtains current pool size
    #
    def size
      @idle.size + @busy.size
    end

    def full?
      size >= @max_size
    end

    def include?(connection)
      idle?(connection) || busy?(connection)
    end

    # Get a connection and release it back to the pool after done with it.
    #
    def with_connection(options = {})
      begin
        connection = get options
        yield connection
      ensure
        if connection
          release connection
        end
      end
    end

    # Gets a connection; timing out if there are none available and it takes longer
    # than specified to create a new one or wait for one to be released.
    # Callers must be release the connection when they are done with it.
    #
    def get(options = {})
      timeout  = options.fetch(:timeout, @timeout)
      deadline = Time.now.utc.to_f + timeout
      sync do
        loop do
          raise PoolShuttingdownError, 'Can not obtain any connection while shutting down.' if @shutdown
          _, connection = @idle.shift
          if connection
            @busy[connection.object_id] = connection
            return connection
          end

          # try to creat a new connection.
          #
          unless full?
            connection = @create_proc.call
            if connection
              @idle[connection.object_id] = connection
              signal_available
            end
          else
            STDOUT.puts 'Pool is full, waiting for a connection released...'
            to_wait = deadline - Time.now.utc.to_f
            raise TimeoutError, "Could not obtain a connection within #{timeout} seconds" if to_wait <= 0
            wait_available to_wait
          end
        end # loop
      end
    end

    # Releases a connection obtained from this pool back into the pool of available connections.
    # It is an error to release a connection not obtained from this pool.
    #
    # @param connection to release.
    #
    def release(connection)
      sync do
        return if @shutdown
        raise ConnectionNotFoundError, "Could not find the connection #{connection.inspect}. Please confirm the connection is obtained from the pool." unless busy?(connection)
        @busy.delete connection.object_id
        @idle[connection.object_id] = connection
        signal_available
      end
    end

    # Removes a connection obtained from this pool from its available connections.
    # It is an error to remove a connection not obtained from this pool.
    #
    # @param connection to remove.
    #
    def remove(connection)
      sync do
        raise ConnectionNotFoundError, "Could not find the connection #{connection.inspect}. Please confirm the connection is obtained from the pool." unless busy?(connection)
        @busy.delete connection.object_id
        signal_available
      end
    end

    # Close the pool. This will disallow further gets from this pool and
    # close all idle connection and any outstanding connection when they are released.
    #
    def shutdown(&block)
      sync do
        @shutdown = true
        max_retry_times = 3
        begin
          @busy.each do |_, connection|
            @busy.delete connection.object_id
            @idle[connection.object_id] = connection
          end
          @idle.each do |_, connection|
            if connection.respond_to? :close
              connection.public_send :close
            elsif block_given?
              if block.arity > 0
                block.call connection
              else
                block.call
              end
            end
          end
          @busy = {}
          @idle = {}
        rescue
          retry if (max_retry_times -= 1) > 0
        ensure
          @shutdown = true
        end
      end
    end
    alias_method :close, :shutdown

    private

      def busy?(connection)
        @busy.key? connection.object_id
      end

      def idle?(connection)
        @idle.key? connection.object_id
      end

      def sync(&block)
        @lock.synchronize { yield }
      end

      # Releases the lock held in mutex and waits; reacquires the lock on wakeup.
      #
      def wait_available(timeout = nil)
        @available.wait(@lock, timeout)
      end

      # Wakes up the first thread in line waiting for this lock.
      #
      def signal_available
        @available.signal
      end

  end # ConnectionPool
end # ProxyPump
