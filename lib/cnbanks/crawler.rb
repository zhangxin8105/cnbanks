require 'oga'
require 'http'
module CNBanks
  module Crawler

    class << self

      def crawl_banks(&block)
        with_retry do
          res = HTTP.get "#{Const::SOURCE_URL}/bank/"
          if res.status.success?
            html = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
            data = html.xpath(Const::BANKS_XPATH).map do |node|
              type_id = node.get('href')[/\A\/bank\/(\d+\w+)\/?/, 1]
              name = node.text.strip
              { type_id: type_id, name: name }
            end
            block_given? ? yield(data) : data
          end
        end
      end

      def crawl_bank_regions(type_id, &block)
        with_retry do
          url = "#{Const::SOURCE_URL}/bank/#{type_id}/"
          STDOUT.puts url
          res = HTTP.get url
          if res.status.success?
            html = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
            data = html.xpath(Const::PROVINCE_XPATH).inject({}) do |data, province|
              path = province.get('href')
              key  = path[/\A\/bank\/\w+\/([A-Za-z]+)\/?/, 1]
              data[key] ||= []
              url  = "#{Const::SOURCE_URL}#{path}"
              puts url
              res  = HTTP.get url
              if res.status.success?
                subhtml = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
                subhtml.xpath(Const::CITY_XPATH).each do |city|
                  href = city.get('href')
                  item = href[/\A\/bank\/\w+\/([A-Za-z]+)\/?/, 1]
                  data[key] << item
                end
              end
              data
            end
            block_given? ? yield(data) : data
          end
        end
      end

      # 获取银行分行数据
      def crawl_bank_branches(type_id, city, page = 1, &block)
        with_retry do
          url = "#{Const::SOURCE_URL}/bank/#{type_id}/#{city}/#{page}/"
          STDOUT.puts url
          res = HTTP.get url
          if res.status.success?
            html = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
            res  = HTTP.get url
            next_page = html.at_xpath Const::NEXT_PAGE_XPATH
            if next_page
              next_page = next_page.get('href')[/\A\/bank\/\w+\/\w+\/(\d+)\/?/, 1]
              next_page = next_page.to_i
            end
            html.xpath(Const::ENTRY_XPATH).each do |tr|
              bank           = { type_id: type_id }
              bank[:code]    = tr.at_xpath('td[1]').text.strip
              bank[:name]    = tr.at_xpath('td[2]/a').text.strip
              bank[:tel]     = tr.at_xpath('td[3]').text.strip
              bank[:zipcode] = tr.at_xpath('td[4]').text.strip
              bank[:address] = tr.at_xpath('td[5]').text.strip
              url = "#{Const::SOURCE_URL}/bank/#{bank[:code]}/"
              STDOUT.puts url
              res = HTTP.get url
              if res.status.success?
                html            = Oga.parse_html(res.to_s.force_encoding(Encoding::UTF_8))
                bank[:province] = html.at_xpath(Const::BANK_PROVINCE_XPATH).text
                bank[:city]     = html.at_xpath(Const::BANK_CITY_XPATH).text
              end
              yield bank
            end
            next_page
          end
        end
      end

      private

        def with_retry(times = 2, &block)
          retry_times = 0
          begin
            yield
          rescue => e
            STDERR.puts e.message + e.backtrace.join("\n")
            if (retry_times += 1) > times
              sleep 0.5 * retry_times
              STDOUT.puts "Oops！retry #{retry_times}."
              retry
            end
          end
        end

    end # ClassMethods

  end # Crawler
end # CNBanks
