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
  class << self

    def db
      @db ||= Database.establish_connection
    end

    def migrate
      db.execute_batch Const::MIGRATE_SQL
    end

    def crawl(options = {})
      crawl_banks
      crawl_bank_branches options
      nil
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
        next_page    = options.fetch(:page, 1)
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

  end
end

at_exit { CNBanks.db.shutdown }
