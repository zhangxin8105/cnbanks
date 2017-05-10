module CNBanks
  class ThreadPool

    FORCE_SHUTDOWN_GRACE_TIME = 3.freeze

    attr_reader :min, :max

    def initialize(min, max = nil)
      @min = min
      @max = max
      @lock = Mutex.new
      @tasks = Queue.new
      @workers = Array.new
      @spawned = 0
      @idle = 0
      @shutdown = false
      sync { min.times { _spawn_thread } }
    end

    # Show how many tasks in queue.
    def backlog
      @tasks.size
    end

    def spawned
      sync { @spawned }
    end

    alias :size :spawned

    def idle
      sync { @idle }
    end

    # Add task to pool.
    def schedule(*args, &block)
      tap do
        sync do
          raise 'Unable to add more tasks while shutting down' if @shutdown
          _schedule(*args, &block)
          # Try to spawn a new thread to run task if not enough.
          _spawn_thread if _short_handed?
        end
      end
    end

    alias :<< :schedule

    def shutdown(timeout = nil)
      workers = sync do
        @shutdown = true
        @cutdown_thread.wakeup if @cutdown_thread && @cutdown_thread.alive?
        @cleanup_thread.wakeup if @cleanup_thread && @cleanup_thread.alive?
        @workers.dup
      end
      timeout = timeout.to_i
      if timeout <= 0
        # Gracefully shutdown, wait for all threads to finish.
        workers.size.times { _schedule { throw :exit } }
        workers.each(&:join)
      else
        # Wait for threads to finish after specified timeout seconds.
        # If there are unfinished threads, then force kill them.
        timeout.times do
          # If the time limit expires, nil will be returned,
          # otherwise thread is returned, then delete it.
          workers.reject! { |t| t.join 1 }
          break if workers.empty?
          sleep 1
        end
        # If pool is no empty, then force to shutdown by raising exception.
        workers.each { |t| t.raise ForceShutdownError }
        workers.each { |t| t.join FORCE_SHUTDOWN_GRACE_TIME }
      end
    end

    # If there are too many idle threads, tell one to exit.
    def cutdown(force = false)
      tap do
        sync do
          if (force || @idle > 0) && @spawned > @min
            th = @workers.detect { |t| t[:idle] }
            STDOUT.puts 'found an idle thread.'
            if th.exit
              @workers.delete th
              @spawned -= 1
            end
          end
        end
      end
    end

    def auto_cutdown!(interval = 20)
      @cutdown_thread ||= Thread.new do
        until @shutdown
          STDOUT.puts "cutdown idle threads at #{Time.now.utc}"
          layoff
          sleep interval
        end
      end
    end

    # IF there are dead threads in pool, clean up them, keep the pool healthy.
    def cleanup
      sync do
        dead_workers = @workers.reject!(&:alive?)
        STDOUT.puts "found #{dead_workers.count} dead threads."
        dead_workers.each do |t|
          # ?? Same as #exit or #terminate
          t.kill
          @spawned -= 1
        end
        @workers.reject! { |t| dead_workers.include? t }
      end
    end

    def auto_cleanup!(interval = 5)
      @cleanup_thread ||= Thread.new do
        until @shutdown
          STDOUT.puts "cleanup dead threads at #{Time.now.utc}"
          cleanup
          sleep interval
        end
      end
    end

    protected

    def sync(&block)
      @lock.synchronize { yield }
    end

    private

    class ForceShutdownError < RuntimeError ; end

    def _short_handed?
      @idle < @tasks.size && @spawned < @max.to_i
    end

    def _schedule(*args, &block)
      @tasks << [block, args]
    end

    # Create a new thread to receive task.
    def _spawn_thread
      @spawned += 1
      thread = Thread.new do
        catch(:exit) do
          loop do
            break if @shutdown && @tasks.empty?
            @idle += 1
            Thread.current[:idle] = true
            task, args = @tasks.pop
            @idle -= 1
            Thread.current[:idle] = false
            # Ignore exceptions to prevent the thread to be killed.
            begin
              task.call *args
            rescue => e
              STDERR.puts "#{e.message} \n\t" + e.backtrace.join("\n\t")
              e
            end
          end # loop
        end # catch
        # If go here, indicate that the pool is shutting down, let's remove the thread.
        sync do
          @spawned -= 1
          @workers.delete thread
        end
      end # Thread.new
      @workers << thread
      thread
    end

  end # ThreadPool
end
