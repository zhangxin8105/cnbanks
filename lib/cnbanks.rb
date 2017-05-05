require 'ruby-pinyin'
require 'core_ext/string'
require 'cnbanks/version'
require 'cnbanks/const'
require 'cnbanks/database'
require 'cnbanks/crawler'
require 'cnbanks/bank'
require 'cnbanks/bank_branch'
require 'cnbanks/cli'
module CNBanks

  CRAWL_INTERVAL = 7*24*60*60.freeze

  class << self

    def db
      @db ||= Database.establish_connection
    end

    def migrate
      db.execute_batch Const::MIGRATE_SQL
    end

    def crawl(options = {})
      begin
        daemonize = options.delete :daemonize
        pidfile   = options.delete :pidfile
        logfile   = options.delete :logfile

        if logfile
          FileUtils.mkdir_p(File.dirname(logfile), mode: 0755)
          FileUtils.touch logfile
          File.chmod(0644, logfile)
          STDERR.reopen(logfile, 'a')
          STDOUT.reopen(STDERR)
          STDOUT.sync = STDERR.sync = true
        else
          STDERR.reopen('/dev/null', 'a')
          STDOUT.reopen(STDERR)
          STDOUT.sync = STDERR.sync = true
        end

        if daemonize
          STDOUT.puts <<-HEREDOC.strip_heredoc
          => Start crawling
          * Daemonizing...
          HEREDOC
          Process.daemon true
          if pidfile
            write_pidfile pidfile
          end
          trap_signals
          loop do
            crawl_banks
            crawl_bank_branches options
            sleep CRAWL_INTERVAL
          end
        else
          STDOUT.puts <<-HEREDOC.strip_heredoc
          => Start crawling
          * Use Ctrl-C to stop
          HEREDOC
          crawl_banks
          crawl_bank_branches options
        end
      rescue  => e
        STDERR.puts e.message << e.backtrace.join("\n")
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
            bank = Bank.new(type_id: item[:type_id], name: item[:name])
            bank.save
          else
            bank.update(type_id: item[:type_id], name: item[:name])
          end
        end
      end
    end

    def crawl_bank_branches(options = {})
      default_opts = { force: false }
      options      = default_opts.merge! options
      banks        = if options[:type]
                        bank = Bank.find_by_type_id options[:type]
                        bank ? [bank] : []
                     else
                        Bank.all
                     end

      Bank.all.each do |bank|
        next_page    = options.fetch(:index, 1)
        next_page    = 1 if options[:force]
        done         = false
        until done
          Crawler.crawl_bank_branches(bank.type_id, next_page) do |data|
            data[:banks].each do |attrs|
              branch = BankBranch.find_by_code attrs[:code]
              if branch
                branch.update attrs
              else
                branch = BankBranch.new attrs
                branch.save
              end
            end
            bank.update(current_page: next_page)
            if data[:next_page] && data[:next_page].to_i > next_page
              next_page = data[:next_page]
            else
              done = true
            end
          end
        end
      end
    end

    def banks
      CNBanks::Bank.all
    end

    def query_by_pinyin_abbr(abbr)
      CNBanks::BankBranch.query_by_pinyin_abbr abbr
    end

    def find_by_code(code)
      CNBanks::BankBranch.find_by_code code
    end

    def query_by_name(bank_name)
      CNBanks::BankBranch.query_by_name bank_name
    end

    private

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
          at_exit { delete_pidfile }
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
          Process.kill(0, pid)
          :running
        rescue Errno::ESRCH
          :dead
        rescue Errno::EPERM
          :not_owned
        end
      end

  end
end

at_exit { CNBanks.db.shutdown }
