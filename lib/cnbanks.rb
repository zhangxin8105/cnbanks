require 'fileutils'
require 'ruby-pinyin'
require 'core_ext/string'
require 'cnbanks/version'
require 'cnbanks/const'
require 'cnbanks/database'
require 'cnbanks/crawler'
require 'cnbanks/bank'
require 'cnbanks/bank_branch'
require 'cnbanks/memory'
require 'cnbanks/thread_pool'
require 'cnbanks/cli'
module CNBanks

  CRAWL_INTERVAL = 30*24*60*60.freeze # 1 month

  class << self

    def db
      @db ||= Database.establish_connection
    end

    def migrate
      db.execute_batch Const::MIGRATE_SQL
    end

    def banks
      Bank.all
    end

    def query_by_pinyin_abbr(abbr)
      BankBranch.query_by_pinyin_abbr abbr
    end

    def query_by_code(code)
      BankBranch.query_by_code code
    end

    def query_by_name(bank_name)
      BankBranch.query_by_name bank_name
    end

    def crawl(options = {})
      begin
        if options.delete(:daemonize)
          STDOUT.puts <<-HEREDOC.strip_heredoc
          => Start crawling
          * Daemonizing...
          HEREDOC
          daemonize
        else
          STDOUT.puts <<-HEREDOC.strip_heredoc
          => Start crawling
          * Use Ctrl-C to stop
          HEREDOC
        end

        if pidfile = options.delete(:pidfile)
          write_pidfile pidfile
        end

        if logfile = options.delete(:logfile)
          redirect_log logfile
        end

        trap_signals

        interval = options.fetch(:interval, CRAWL_INTERVAL)

        STDOUT.puts "==> Start crawling at #{Time.now.utc}"
        loop do
          crawl_banks
          crawl_bank_branches options
          STDOUT.puts "==> Next time at #{Time.now.utc + interval}"
          sleep interval
        end

      rescue => e
        STDERR.puts e.message + e.backtrace.join("\n")
      end
    end

    def dump(sql_path)
      `sqlite3 cnbanks.db .dump > #{sql_path}`
    end

    def crawl_banks
      Crawler.crawl_banks do |list|
        list.each do |item|
          bank = Bank.find_by_type_id item[:type_id]
          unless bank
            bank = Bank.new(type_id: item[:type_id], name: item[:name], active: 1)
            bank.save
          else
            bank.update(type_id: item[:type_id], name: item[:name])
          end
        end
      end
    end

    def crawl_bank_branches(options = {})
      banks = if type_id = options[:type]
                bank = Bank.find_by_type_id type_id
                bank ? [bank] : []
              else
                Bank.all
              end
      force = !!options[:force]
      @tp = init_threads_pool(Integer(options.fetch(:threads, 5)))
      puts "Use threads min: #{@tp.min}, max: #{@tp.max}"
      banks.each do |bank|
        Crawler.crawl_bank_regions(bank.type_id) do |regions|
          regions.each do |province, cities|
            if options[:province].nil? || province == options[:province]
              cities.each do |city|

                if options[:city].nil? || city == options[:city]
                  @tp.schedule(bank.type_id, province, city) do |type_id, province_pinyin, city_pinyin|
                    memory = CNBanks::Memory.find(type_id, province_pinyin, city_pinyin)
                    unless memory
                      memory = CNBanks::Memory.new(
                        type_id: type_id,
                        province_pinyin: province_pinyin,
                        city_pinyin: city_pinyin,
                        page: 1
                      )
                      memory.save
                      memory = CNBanks::Memory.find(type_id, province_pinyin, city_pinyin)
                    end
                    current_page = force ? 1 : memory.page
                    loop do
                      next_page = Crawler.crawl_bank_branches(type_id, city_pinyin, current_page) do |attrs|
                        branch  = BankBranch.find_uniq(attrs[:code], attrs[:name])
                        if branch
                          branch.update attrs
                        else
                          branch = BankBranch.new attrs
                          branch.save
                        end
                        branch = nil
                      end
                      if next_page && next_page.to_i > current_page
                        current_page = next_page
                        memory.update(page: current_page)
                      else
                        memory = nil
                        break
                      end
                    end # loop
                  end
                end

              end # cities
            end
          end # regions
        end
      end
    end

    private

      def daemonize
        Process.daemon true
      end

      def trap_signals
        # Gracefully shutdown
        %i(QUIT INT TERM).each do |signal|
          trap(signal) do
            STDOUT.puts '- Goodbye!'
            exit
          end
        end
      end

      def write_pidfile(path)
        max_retry_time = 3
        begin
          FileUtils.mkdir_p(File.dirname(path), mode: 0755)
          File.open(path, ::File::CREAT | ::File::EXCL | ::File::WRONLY) { |f| f.write Process.pid }
          at_exit { delete_pidfile path }
        rescue Errno::EEXIST
          check_pid! path
          if (max_retry_time -= 1) > 0
            sleep 0.5
            retry
          end
        end
      end

      def check_pid!(path)
        case pidfile_status
        when :running, :not_owned
          STDERR.puts "A crawler is already running. Check #{path}"
          exit 1
        when :dead
          delete_pidfile path
        end
      end

      def delete_pidfile(path)
        File.unlink(path) if ::File.exists? path
      end

      def pidfile_status(path)
        begin
          return :exited unless ::File.exists? path
          pid = File.read(path).to_i
          return :dead if pid.zero?
          # Check the process status.
          # The keys and values of {Signal.list} are known signal names and numbers, respectively.
          Process.kill(:EXIT, pid)
          :running
        rescue Errno::ESRCH
          :dead
        rescue Errno::EPERM
          :not_owned
        end
      end

      def redirect_log(path)
        FileUtils.mkdir_p(File.dirname(path), mode: 0755)
        FileUtils.touch path
        File.chmod(0644, path)
        STDERR.reopen(path, 'a')
        STDOUT.reopen(STDERR)
        STDOUT.sync = STDERR.sync = true
      end

      def init_threads_pool(max_count)
        pool ||= ThreadPool.new(1, max_count)
        pool.auto_cutdown!
        pool.auto_cleanup!
        pool
      end

  end
end

at_exit do
 @db.shutdown if @db
 @tp.shutdown if @tp
end
