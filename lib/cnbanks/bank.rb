require 'cnbanks/const'
module CNBanks
  class Bank

    def self.column_names
      %i(id type_id name pinyin_abbr active)
    end

    def self.find_by_name(name)
      row = CNBanks.db.execute(Const::FIND_BANK_BY_NAME_SQL, name).first
      orm row
    end

    def self.find_by_type_id(type_id)
      row = CNBanks.db.execute(Const::FIND_BANK_BY_TYPE_ID_SQL, type_id).first
      orm row
    end

    def self.count
      CNBanks.db.execute(Const::BANKS_COUNT_SQL).first[0]
    end

    def self.all
      CNBanks.db.execute(Const::ALL_BANKS_SQL).map { |row| orm row }
    end

    def self.orm(row)
      if row && !row.empty?
        new column_names.zip(row).to_h
      end
    end

    attr_accessor :id, :type_id, :name, :pinyin_abbr, :active

    def initialize(options = {})
      @id               = options[:id]
      @type_id          = options[:type_id]
      @name             = options[:name]
      @pinyin_abbr      = options[:pinyin_abbr]
      @active           = options[:active].to_i
    end

    def [](column)
      column = column.to_s.to_sym
      self.public_send column
    end

    def save
      if name
        @pinyin_abbr ||= name.pinyin_abbr
      end
      CNBanks.db.execute(
        Const::INERT_BANK_SQL,
        type_id,
        name,
        pinyin_abbr,
        active
      )
    end

    def update(attrs = {})
      attrs = to_h.merge! attrs
      if attrs[:name]
        attrs[:pinyin_abbr] ||= attrs[:name].pinyin_abbr
      end
      CNBanks.db.execute(
        Const::UPDATE_BANK_SQL,
        attrs[:type_id],
        attrs[:name],
        attrs[:pinyin_abbr],
        attrs[:active],
        id
      )
    end

    def to_h
      { id: id, type_id: type_id, name: name, pinyin_abbr: pinyin_abbr, active: active }
    end

  end
end
