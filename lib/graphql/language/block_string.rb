# frozen_string_literal: true
module GraphQL
  module Language
    module BlockString
      # Precompile some of these, but don't
      # accept new entries or else user input could make an ever-expanding hash.
      REPLACE_REGEXPS = {}
      TRAILING_REGEXPS = {}
      LEADING_REGEXPS = {}

      1.upto(10) do |i|
        REPLACE_REGEXPS[i] = Regexp.compile("^ {#{i}}")
        TRAILING_REGEXPS[i] = Regexp.compile('\A(?:\n +|^ +\n)+', Regexp::MULTILINE)
        LEADING_REGEXPS[i] = Regexp.compile('(?:\n *)+\Z', Regexp::MULTILINE)
      end

      REPLACE_REGEXPS.freeze
      TRAILING_REGEXPS.freeze
      LEADING_REGEXPS.freeze

      # Remove leading and trailing whitespace from a block string.
      # See "Block Strings" in https://github.com/facebook/graphql/blob/master/spec/Section%202%20--%20Language.md
      def self.trim_whitespace(str)
        # Early return for the most common cases:
        if str == ""
          return ""
        elsif !(has_newline = str.include?("\n")) && !(begins_with_whitespace = str.start_with?(" "))
          return str
        end

        common_indent = nil
        current_indent = 0
        current_length = 0
        begin_line = true
        first_line = true
        str.each_codepoint do |ord|
          case ord
          when 10 # "\n"
            if first_line
              first_line = false
            elsif current_indent < current_length && (common_indent.nil? || current_indent < common_indent)
              common_indent = current_indent
            end
            begin_line = true
            current_indent = 0
            current_length = 0
          when 32 # " "
            if begin_line
              current_indent += 1
            end
            current_length += 1
          else
            begin_line = false
            current_length += 1
          end
        end

        replace_regexp = if common_indent && common_indent > 0
          REPLACE_REGEXPS[common_indent] || Regexp.compile("^ {0,#{common_indent}}")
        else
          nil
        end

        # We're gonna modify the string, dup it if need be
        if str.frozen? && (str.start_with?("\n") || str.end_with?("\n") || (replace_regexp && str.match?(replace_regexp)))
          str = str.dup
        end

        # Replace common whitespace
        if replace_regexp
          str.gsub!(replace_regexp, "")
        end
        # Remove leading & trailing blank lines
        leading_replace_regexp = LEADING_REGEXPS[common_indent] || Regexp.compile('\A(?:\n {0,' + common_indent.to_s + '})+', Regexp::MULTILINE)
        trailing_replace_regexp = TRAILING_REGEXPS[common_indent] || Regexp.compile('(?:\n {0,' + common_indent.to_s + '})+\Z', Regexp::MULTILINE)

        res = nil
        while (res = str.slice!(leading_replace_regexp))
        end

        while (res = str.slice!(trailing_replace_regexp))
        end


        str
      end

      def self.print(str, indent: '')
        lines = str.split("\n")

        block_str = "#{indent}\"\"\"\n".dup

        lines.each do |line|
          if line == ''
            block_str << "\n"
          else
            sublines = break_line(line, 120 - indent.length)
            sublines.each do |subline|
              block_str << "#{indent}#{subline}\n"
            end
          end
        end

        block_str << "#{indent}\"\"\"\n".dup
      end

      private

      def self.break_line(line, length)
        return [line] if line.length < length + 5

        parts = line.split(Regexp.new("((?: |^).{15,#{length - 40}}(?= |$))"))
        return [line] if parts.length < 4

        sublines = [parts.slice!(0, 3).join]

        parts.each_with_index do |part, i|
          next if i % 2 == 1
          sublines << "#{part[1..-1]}#{parts[i + 1]}"
        end

        sublines
      end
    end
  end
end
