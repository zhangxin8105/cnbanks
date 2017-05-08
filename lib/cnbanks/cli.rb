require 'optparse'
require 'json'

module CNBanks
  module CLI

    class << self

      def start(args)
        CNBanks.migrate

        options = {}

        global_opts_parser = OptionParser.new do |opts|
          opts.banner = 'Usage: cnbanks [command] [options]'
          opts.separator <<-SEP.strip_heredoc
          Available Commands:
          list   [options] List banks
          crawl  [options] Crawl data
          stop   [options] Stop crawling
          search [options] Search banks via name，code，pinyin abbr
          See 'cnbanks COMMAND --help' for more information on a specific command
          SEP
        end

        cmd_list_opts_parser = OptionParser.new do |opts|
          opts.banner = 'Usage: list [options]'
          opts.on('-j', '--json', 'Show in JSON mode') { options[:json] = true }
          opts.on('-h', '--help', 'Show help') do
            puts opts
            exit
          end
        end

        cmd_crawl_opts_parser = OptionParser.new do |opts|
          opts.banner = 'Usage: crawl [options]'
          opts.on('-d', '--daemonize', 'Run in daemonize') { options[:daemonize] = true }
          opts.on('-f', '--force', 'Force to crawl data') { options[:force] = true }
          opts.on('-p FILE', '--pidfile FILE', 'PID file') { |path| options[:pidfile] = path }
          opts.on('-l FILE', '--logfile FILE', 'Log file') { |path| options[:logfile] = path }
          opts.on('-i Integer', '--index Integer', 'From specified page index') { |page| options[:index] = page.to_i }
          opts.on('-t TYPE', '--type TYPE', 'Crawl with specified Bank Type ID') { |type| options[:type] = type }
          opts.on('-h', '--help', 'Show help') do
            puts opts
            exit
          end
        end

        cmd_stop_opts_parser = OptionParser.new do |opts|
          opts.banner = 'Usage: stop [options]'
          opts.on('-f', '--force', 'Force to stop crawling') { options[:force] = true }
          opts.on('-p FILE', '--pidfile FILE', 'PID file') { |path| options[:pidfile] = path }
          opts.on('-h', '--help', 'Show help') do
            puts opts
            exit
          end
        end

        cmd_search_opts_parser = OptionParser.new do |opts|
          opts.banner = 'Usage: search [options]'
          opts.on('-c CODE', '--code CODE', 'Find via Bank Code') { |code| options[:code] = code }
          opts.on('-p PINYIN_ABBR', '--pinyin-abbr PINYIN_ABBR', 'Query via PinYin abbr') { |pinyin_abbr| options[:pinyin_abbr] = pinyin_abbr }
          opts.on('-n NAME', '--name NAME', 'Query via Bank Name') { |name| options[:name] = name }
          opts.on('-o FILE', '--output FILE', 'Export to specified JSON file') { |path| options[:output] = path }
          opts.on('-h', '--help', 'Show help') do
            puts opts
            exit
          end
        end

        cmd_opts_parsers = {
          list:   cmd_list_opts_parser,
          crawl:  cmd_crawl_opts_parser,
          stop:   cmd_stop_opts_parser,
          search: cmd_search_opts_parser
        }

        cmd = args.shift
        cmd = cmd.to_sym if cmd
        unless cmd && cmd_opts_parsers.has_key?(cmd)
          puts global_opts_parser
          exit
        end

        opts_parser = cmd_opts_parsers[cmd]
        opts_parser.parse args

        case cmd
        when :list
          banks = CNBanks.banks
          if options[:json]
            banks = banks.map(&:to_h)
            dump_or_print_json banks, options[:output]
          else
            puts "TYPE_ID\tBANK_NAME"
            puts banks.map { |bank| "#{bank.type_id}\t#{bank.name}" }
          end
        when :crawl
          CNBanks.crawl options
        when :stop
          begin
            pidfile = options[:pidfile]
            if File.exists?(pidfile)
              pid = File.read(pidfile).to_i
              if options[:force]
                Process.kill(:KILL, pid)
              else
                Process.kill(:INT, pid)
              end
            end
          rescue => e
            STDOUT.puts e.message
          end
        when :search
          if options.empty?
            puts opts_parser
            exit
          end
          puts 'Searching ...'
          if options[:pinyin_abbr]
            banks = CNBanks.query_by_pinyin_abbr options[:pinyin_abbr]
            if banks
              banks = banks.map(&:to_h)
              dump_or_print_json banks, options[:output]
            end
          elsif options[:name]
            banks = CNBanks.query_by_name options[:name]
            if banks
              banks = banks.map(&:to_h)
              dump_or_print_json banks, options[:output]
            end
          elsif options[:code]
            bank = CNBanks.find_by_code options[:code]
            if bank
              dump_or_print_json bank.to_h, options[:output]
            end
          end
        end

      end

      def dump_or_print_json(data, path = nil)
        json = JSON.pretty_generate data
        if path
          File.open(path, 'w') { |f| f.puts json }
        else
          puts json
        end
      end

    end

  end
end
