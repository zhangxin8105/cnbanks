require 'cnbanks/const'
module CNBanks
  class BankBranch

    def self.column_names
      %i(id type_id code name pinyin_abbr province province_pinyin province_pinyin_abbr city city_pinyin city_pinyin_abbr address tel zipcode)
    end

    def self.find_by_code(code)
      row = CNBanks.db.execute(Const::FIND_BANK_BRANCH_BY_CODE_SQL, code).first
      orm row
    end

    def self.query_by_pinyin_abbr(abbr)
      CNBanks.db.execute(Const::QUERY_BANK_BRANCHES_BY_PINYIN_ABBR_SQL, "%#{abbr.downcase}%").map { |row| orm row }
    end

    def self.query_by_name(bank_name)
      CNBanks.db.execute(Const::QUERY_BANK_BRANCHES_BY_NAME_SQL, "%#{bank_name}%").map { |row| orm row }
    end

    def self.count
      CNBanks.db.execute(Const::BANK_BRANCHES_COUNT_SQL).first[0]
    end

    def self.orm(row)
      if row && !row.empty?
        new column_names.zip(row).to_h
      end
    end

    attr_accessor :id, :type_id, :code, :name, :pinyin_abbr
    attr_accessor :province, :province_pinyin, :province_pinyin_abbr
    attr_accessor :city, :city_pinyin, :city_pinyin_abbr
    attr_accessor :tel, :address, :zipcode

    def initialize(options = {})
      @id                   = options[:id]
      @type_id              = options[:type_id]
      @code                 = options[:code]
      @name                 = options[:name]
      @pinyin_abbr          = options[:pinyin_abbr]
      @province             = options[:province]
      @province_pinyin      = options[:province_pinyin]
      @province_pinyin_abbr = options[:province_pinyin_abbr]
      @city                 = options[:city]
      @city_pinyin          = options[:city_pinyin]
      @city_pinyin_abbr     = options[:city_pinyin_abbr]
      @address              = options[:address]
      @tel                  = options[:tel]
      @zipcode              = options[:zipcode]
    end

    def [](column)
      column = column.to_s.to_sym
      self.public_send column
    end

    def save
      if name
        @pinyin_abbr          ||= name.pinyin_abbr
      end
      if province
        @province_pinyin      ||= province.pinyin
        @province_pinyin_abbr ||= province.pinyin_abbr
      end
      if city
        @city_pinyin          ||= city.pinyin
        @city_pinyin_abbr     ||= city.pinyin_abbr
      end
      CNBanks.db.execute(Const::INERT_BANK_BRANCH_SQL, type_id, code, name, pinyin_abbr, province, province_pinyin, province_pinyin_abbr, city, city_pinyin, city_pinyin_abbr, address, tel, zipcode)
    end

    def update(attrs = {})
      attrs = to_h.merge! attrs
      if attrs[:name]
        attrs[:pinyin_abbr]          ||= attrs[:name].pinyin_abbr
      end
      if attrs[:province]
        attrs[:province_pinyin]      ||= attrs[:province].pinyin
        attrs[:province_pinyin_abbr] ||= attrs[:province].pinyin_abbr
      end
       if attrs[:city]
        attrs[:city_pinyin]          ||= attrs[:city].pinyin
        attrs[:city_pinyin_abbr]     ||= attrs[:city].pinyin_abbr
      end
      CNBanks.db.execute(
        Const::UPDATE_BANK_BRANCH_SQL, 
        attrs[:type_id], attrs[:code], attrs[:name], attrs[:pinyin_abbr],
        attrs[:province], attrs[:province_pinyin], attrs[:province_pinyin_abbr],  
        attrs[:city], attrs[:city_pinyin], attrs[:city_pinyin_abbr],
        attrs[:address], attrs[:tel], attrs[:zipcode],
        id
      )
    end

    def to_h
      { 
        id: id, type_id: type_id, code: code,  name: name, pinyin_abbr: pinyin_abbr, 
        province: province, province_pinyin: province_pinyin, province_pinyin_abbr: province_pinyin_abbr, 
        city: city, city_pinyin: city_pinyin, city_pinyin_abbr: city_pinyin_abbr,
        address: address, tel: tel, zipcode: zipcode
      }
    end

  end
end
