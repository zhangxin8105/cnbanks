require 'cnbanks/const'
module CNBanks
  class Memory

    def self.column_names
      %i(id type_id province_pinyin city_pinyin page)
    end

    def self.find(type_id, province_pinyin, city_pinyin)
      row = CNBanks.db.execute(Const::FIND_MEMORY_SQL, type_id, province_pinyin, city_pinyin).first
      orm row
    end

    def self.orm(row)
      if row && !row.empty?
        new column_names.zip(row).to_h
      end
    end

    attr_accessor :id, :type_id, :province_pinyin, :city_pinyin, :page

    def initialize(options = {})
      @id               = options[:id]
      @type_id          = options[:type_id]
      @province_pinyin  = options[:province_pinyin]
      @city_pinyin      = options[:city_pinyin]
      @page             = options[:page] || 1
    end

    def save
      CNBanks.db.execute(
        Const::INSERT_MEMORY_SQL,
        type_id,
        province_pinyin,
        city_pinyin,
        page
      )
    end

    def update(attrs = {})
      attrs = to_h.merge! attrs
      CNBanks.db.execute(
        Const::UPDATE_MEMORY_SQL,
        attrs[:type_id],
        attrs[:province_pinyin],
        attrs[:city_pinyin],
        attrs[:page],
        id
      )
    end

    def to_h
      { id: id, type_id: type_id, province_pinyin: province_pinyin, city_pinyin: city_pinyin, page: page }
    end

  end
end
