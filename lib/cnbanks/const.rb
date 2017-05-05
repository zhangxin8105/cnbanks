module CNBanks
  module Const
    SOURCE_URL           = 'http://5cm.cn/bank'.freeze
    BANKS_XPATH          = '//html/body/div[2]/div/div[2]/div/ul/li/a'.freeze
    ENTRY_XPATH          = '//html/body/div[2]/div/div[1]/div[2]/table/tr[position() > 1]'.freeze
    BANK_PROVINCE_XPATH  = '//html/body/div[2]/div/div[1]/table/tr[1]/td[2]/a'.freeze
    BANK_CITY_XPATH      = '//html/body/div[2]/div/div[1]/table/tr[1]/td[4]/a'.freeze
    NEXT_PAGE_XPATH      = '//html/body/div[2]/div/div[1]/div[2]/ul[@class="pagination"]/li/a[@class="next"]'.freeze
    MIGRATE_SQL = <<-SQL.strip_heredoc.freeze
    CREATE TABLE IF NOT EXISTS banks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type_id VARCHAR(20),
      name VARCHAR(100),
      pinyin_abbr VARCHAR(30),
      current_page INTEGER DEFAULT 0,
      active INTEGER(4) DEFAULT 1
    );
    CREATE INDEX IF NOT EXISTS index_banks_on_type_id ON banks(type_id);
    CREATE INDEX IF NOT EXISTS index_banks_on_pinyin_abbr ON banks(pinyin_abbr);

    CREATE TABLE IF NOT EXISTS bank_branches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type_id VARCHAR(20),
      code VARCHAR(50),
      name VARCHAR(100),
      pinyin_abbr VARCHAR(50),
      tel VARCHAR(30),
      province VARCHAR(30),
      province_pinyin VARCHAR(50),
      province_pinyin_abbr VARCHAR(20),
      city VARCHAR(30),
      city_pinyin VARCHAR(50),
      city_pinyin_abbr VARCHAR(20),
      address VARCHAR(200),
      zipcode VARCHAR(10),
      FOREIGN KEY(type_id) REFERENCES banks(type_id)
    );
    CREATE INDEX IF NOT EXISTS index_bank_branches_on_code ON bank_branches(code);
    CREATE INDEX IF NOT EXISTS index_bank_branches_on_pinyin_abbr ON bank_branches(pinyin_abbr);
    CREATE INDEX IF NOT EXISTS index_bank_branches_on_province_pinyin_abbr ON bank_branches(province_pinyin_abbr);
    CREATE INDEX IF NOT EXISTS index_bank_branches_on_city_pinyin_abbr ON bank_branches(city_pinyin_abbr);
    SQL

    BACKUP_BANKS_TABLE_SQL = <<-SQL.strip_heredoc.freeze
    ALTER TABLE banks RENAME TO banks_bak
    SQL

    BACKUP_BANK_BRANCHES_TABLE_SQL = <<-SQL.strip_heredoc.freeze
    ALTER TABLE bank_branches RENAME TO bank_branches_bak
    SQL

    ALL_BANKS_SQL = <<-SQL.strip_heredoc.freeze
    SELECT id, type_id, name, pinyin_abbr, current_page FROM banks WHERE active = 1
    SQL

    BANKS_COUNT_SQL = <<-SQL.strip_heredoc.freeze
    SELECT COUNT(*) FROM banks
    SQL

    INERT_BANK_SQL = <<-SQL.strip_heredoc.freeze
    INSERT INTO banks(type_id, name, pinyin_abbr, current_page) VALUES(?, ?, ?, ?)
    SQL

    UPDATE_BANK_SQL = <<-SQL.strip_heredoc.freeze
    UPDATE banks SET type_id = ?, name = ?, pinyin_abbr = ?, current_page = ? WHERE id = ?
    SQL

    FIND_BANK_BY_NAME_SQL = <<-SQL.strip_heredoc.freeze
    SELECT id, type_id, name, pinyin_abbr, current_page FROM banks WHERE name = ?
    SQL

    FIND_BANK_BY_TYPE_ID_SQL = <<-SQL.strip_heredoc.freeze
    SELECT id, type_id, name, pinyin_abbr, current_page FROM banks WHERE type_id = ?
    SQL

    BANK_BRANCHES_COUNT_SQL = <<-SQL.strip_heredoc.freeze
    SELECT COUNT(*) FROM bank_branches
    SQL

    INERT_BANK_BRANCH_SQL = <<-SQL.strip_heredoc.freeze
    INSERT INTO bank_branches(type_id, code, name, pinyin_abbr, province, province_pinyin, province_pinyin_abbr, city, city_pinyin, city_pinyin_abbr, address, tel, zipcode) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    SQL

    UPDATE_BANK_BRANCH_SQL = <<-SQL.strip_heredoc.freeze
    UPDATE bank_branches SET type_id = ?, code = ?, name = ?, pinyin_abbr = ?, province = ?, province_pinyin = ?, province_pinyin_abbr = ?, city = ?, city_pinyin = ?, city_pinyin_abbr = ?, address = ?, tel = ?, zipcode = ? WHERE id = ?
    SQL

    FIND_BANK_BRANCH_BY_CODE_SQL = <<-SQL.strip_heredoc.freeze
    SELECT id, type_id, code, name, pinyin_abbr, province, province_pinyin, province_pinyin_abbr, city, city_pinyin, city_pinyin_abbr, address, tel, zipcode FROM bank_branches WHERE code = ?
    SQL

    QUERY_BANK_BRANCHES_BY_PINYIN_ABBR_SQL = <<-SQL.strip_heredoc.freeze
    SELECT id, type_id, code, name, pinyin_abbr, province, province_pinyin, province_pinyin_abbr, city, city_pinyin, city_pinyin_abbr, address, tel, zipcode FROM bank_branches WHERE pinyin_abbr LIKE ?
    SQL

    QUERY_BANK_BRANCHES_BY_NAME_SQL = <<-SQL.strip_heredoc.freeze
    SELECT id, type_id, code, name, pinyin_abbr, province, province_pinyin, province_pinyin_abbr, city, city_pinyin, city_pinyin_abbr, address, tel, zipcode FROM bank_branches WHERE name LIKE ?
    SQL

  end
end
