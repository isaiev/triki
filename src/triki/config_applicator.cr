class Triki
  module ConfigApplicator
    alias RowAsHash = Hash(String, RowContent)
    alias RowContent = String | Int32 | Nil
    alias Row = Array(RowContent)
    alias Columns = Array(String)
    alias IntRange = Range(Int32, Int32)

    alias BoolProc = Proc(RowAsHash, Bool)
    alias StringProc = Proc(String)

    def self.apply_table_config(row : Array(String?), table_config : Triki::ConfigTableHash, columns : Columns)
      return row unless table_config.is_a?(Hash)

      row_hash = row_as_hash(row, columns)

      my_row = Row.new
      my_row += row

      table_config.each do |column, definition|
        index = columns.index(column)
        raise "ERROR: Column #{column} does not exist" unless index

        definition = { :type => definition } if definition.is_a?(Symbol)

        number = (definition[:number]? || 1).as(Int32)
        between = (definition[:between]? || (0..1000)).as(IntRange)
        one_of = definition[:one_of]?
        length = definition[:length]?
        chars = definition[:chars]?

        if unless_definition = definition[:unless]?
          raise "ERROR: 'unless' definition does not return Bool or Symbol" unless unless_definition.is_a?(BoolProc | Symbol)

          unless_check = make_conditional_method(unless_definition, index, row)

          next if unless_check.call(row_hash)
        end

        if if_definition = definition[:if]?
          raise "ERROR: 'if' definition does not return Bool or Symbol" unless if_definition.is_a?(BoolProc | Symbol)

          if_check = make_conditional_method(if_definition, index, row)

          next unless if_check.call(row_hash)
        end

        if (skip_regexes = definition[:skip_regexes]?).is_a?(Array(Regex))

          next if skip_regexes.any? { |regex| row[index] =~ regex }
        end

        my_row[index] = case definition[:type]
                     when :email
                       md5 = Digest::MD5.hexdigest(rand.to_s)[0...5]
                       clean_quotes("#{Faker::Internet.email}.#{md5}.example.com")
                     when :string
                       random_string(length || 30, chars.as(String | Nil) || SENSIBLE_CHARS) if length.is_a?(Int32)
                     when :lorem
                       clean_bad_whitespace(clean_quotes(Faker::Lorem.sentences(number).join(".  ")))
                     when :like_english
                       clean_quotes random_english_sentences(number)
                     when :name
                       clean_quotes(Faker::Name.name)
                     when :first_name
                       clean_quotes(Faker::Name.first_name)
                     when :last_name
                       clean_quotes(Faker::Name.last_name)
                     when :address
                       clean_quotes("#{Faker::Address.street_address}\\n#{Faker::Address.city}, #{Faker::Address.state_abbr} #{Faker::Address.zip_code}")
                     when :street_address
                       clean_bad_whitespace(clean_quotes(Faker::Address.street_address))
                     when :secondary_address
                       clean_bad_whitespace(clean_quotes(Faker::Address.secondary_address))
                     when :city
                       clean_quotes(Faker::Address.city)
                     when :state
                       clean_quotes Faker::Address.state_abbr
                     when :zip_code
                       Faker::Address.zip_code
                     when :phone
                       clean_quotes Faker::PhoneNumber.phone_number
                     when :company
                       clean_bad_whitespace(clean_quotes(Faker::Company.name))
                     when :ipv4
                       Faker::Internet.ip_v4_address
                     when :ipv6
                       Faker::Internet.ip_v6_address
                     when :url
                       clean_bad_whitespace(Faker::Internet.url)
                     when :integer
                       random_integer(between).to_s
                     when :fixed
                       if one_of.is_a?(Array)
                         one_of.sample.as(String | Int32)
                       else
                         string = definition[:string]

                         if string.is_a?(Proc)
                           if string.is_a?(Proc(Hash(String, RowContent), RowContent))
                             string.call(row_hash)
                           elsif string.is_a?(StringProc)
                             string.call
                           end
                         else
                           string.as(String)
                         end
                       end
                     when :null
                       nil
                     when :keep
                       row[index]?
                     else
                       Log.warn { "Keeping a column value by providing an unknown type (#{definition[:type]}) is deprecated.  Use :keep instead." }
                       row[index]?
                     end
      end
      my_row
    end

    def self.row_as_hash(row : Array, columns : Array) : RowAsHash
      columns.zip(row).each_with_object(RowAsHash.new) do |(name, value),m|
        m[name] = value
      end
    end

    def self.make_conditional_method(conditional_method, index, row) : Proc
      return conditional_method if conditional_method.is_a?(Proc)

      if conditional_method == :blank
        Proc(RowAsHash, Bool).new do
          content = row[index]
          content.nil? || content.empty?
        end
      elsif conditional_method == :nil
        Proc(RowAsHash, Bool).new { row[index].nil? }
      else
        raise RuntimeError.new
      end
    end

    def self.random_integer(between : IntRange) : Int32
      (between.min + (between.max - between.min) * rand).round.to_i
    end

    def self.random_string(length_or_range, chars)
      range = case length_or_range
              when .is_a?(Int32)
                (length_or_range..length_or_range)
              when .is_a?(Range)
                length_or_range
              else
                raise "ERROR: 'length' or 'range' es not an Integer or a Range"
              end

      times = random_integer(range)
      random_string = ""
      times.times do
        random_string += chars[(rand * chars.size).to_i]
      end
      random_string
    end

    def self.walker_method
      @@walker_method ||= begin
                            words = Array(String).new
                            counts = Array(Int32).new
                            File.read(File.expand_path(File.join(__DIR__, "data", "en_50K.txt"))).each_line do |line|
                              word, count = line.split(/\s+/)
                              words << word
                              counts << count.to_i
                            end
                            WalkerMethod.new(words, counts)
                          end
    end

    def self.random_english_sentences(num : Int32)
      sentences = Array(String).new
      num.times do
        words = Array(String).new
        (3 + rand * 5).to_i.times { words << walker_method.random }
        sentence = words.join(" ") + "."
        sentences << sentence.capitalize
      end
      sentences.join(" ")
    end

    def self.clean_quotes(value)
      value.gsub(/['"]/, "")
    end

    def self.clean_bad_whitespace(value)
      value.gsub(/[\n\t\r]/, "")
    end
  end
end
