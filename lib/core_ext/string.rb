class String

  def strip_heredoc
    blank  = scan(/^[ \t]*(?=\S)/).min
    indent = blank ? blank.size : 0
    gsub(/^[ \t]{#{indent}}/, '')
  end unless method_defined? :strip_heredoc

  if defined?(::PinYin)
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
    def pinyin(tone = nil)
      PinYin.of_string(self, tone).join
    end unless method_defined? :pinyin

    # @param tone [true,false,:ascii,:unicode]
    def pinyin_abbr(tone = nil)
      PinYin.abbr(self, tone)
    end unless method_defined? :pinyin_abbr
    RUBY
  end

end
