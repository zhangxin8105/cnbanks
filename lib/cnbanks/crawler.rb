require 'oga'
require 'http'
module CNBanks
  module Crawler

    class << self

      def crawl_banks(&block)
        with_retry do
          res = HTTP.get Const::SOURCE_URL + '/'
          if res.status.success?
            html = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
            banks = html.xpath(Const::BANKS_XPATH).map do |node|
              type_id = node.get('href').gsub(/\A\/bank\/(\d+\w+)\/?/) { $1 }
              name = node.text.strip
              { type_id: type_id, name: name }
            end
            if block_given?
              yield banks
            else
              banks
            end
          end
        end
      end

      # 获取银行分行数据
      def crawl_bank_branches(type_id, page = 1, &block)
        with_retry do
          url = Const::SOURCE_URL + '/' + type_id.to_s + '/' + page.to_s + '/'
          puts url
          res = HTTP.get url
          if res.status.success?
            html      = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
            next_page = html.at_xpath Const::NEXT_PAGE_XPATH
            if next_page
              next_page = next_page.get('href').gsub(/\A\/bank\/\w+\/(\d+)\/?/) { $1 }
              next_page = next_page.to_i
            end
            page_banks = html.xpath(Const::ENTRY_XPATH).map do |tr|
              bank           = { type_id: type_id }
              bank[:code]    = tr.at_xpath('td[1]').text.strip
              bank[:name]    = tr.at_xpath('td[2]/a').text.strip
              bank[:tel]     = tr.at_xpath('td[3]').text.strip
              bank[:zipcode] = tr.at_xpath('td[4]').text.strip
              bank[:address] = tr.at_xpath('td[5]').text.strip
              url = Const::SOURCE_URL + '/' + bank[:code] + '/'
              puts url
              res = HTTP.get url
              if res.status.success?
                html            = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
                bank[:province] = html.at_xpath(Const::BANK_PROVINCE_XPATH).text
                bank[:city]     = html.at_xpath(Const::BANK_CITY_XPATH).text
              end
              bank
            end

            data = { banks: page_banks, next_page: next_page }
            if block_given?
              yield data
            else
              data
            end
          end
        end
      end

      private

        def with_retry(times = 2, &block)
          retry_times = 0
          begin
            yield
          rescue => e
            STDERR.puts "#{e.message} (#{e.class})\n" << e.backtrace.join("\n")
            if (retry_times += 1) > times
              sleep 0.5 * retry_times
              STDOUT.puts "Oops！retry #{retry_times}."
              retry
            end
          end
        end

    end # ClassMethods

  end # Crawler
end # ChinaBanks
