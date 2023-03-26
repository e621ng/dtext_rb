require "dtext/dtext"
require "nokogiri"

module DTextRagel
  class Error < StandardError; end

  def self.parse_inline(str)
    parse(str, :inline => true)
  end

  def self.parse(str, inline: false, disable_mentions: false, allow_color: false, base_url: nil, max_thumbs: 25)
    return nil if str.nil?
    raise TypeError unless str.respond_to?(:gsub)
    str = preprocess_for_tables(str)
    results = c_parse(str, inline, disable_mentions, allow_color, max_thumbs)
    results[0] = resolve_relative_urls(results[0], base_url) if base_url
    results
  end

  private

  def self.preprocess_for_tables(str)
    str.gsub(/(?:\[ltable\])(.*?)(?:\[\/ltable\]|\z)/mi) do
      contents = Regexp.last_match[1].strip
      row_num = 0
      rows = contents.split(/\n/).map do |row|
        cols = row.split(/(?<!\\)\|/).map do |col|
          row_num == 0 ? "[th]#{col}[/th]" : "[td]#{col}[/td]"
        end
        new_row = row_num == 0 ? "[thead][tr]#{cols.join('')}[/tr][/thead][tbody]" : "[tr]#{cols.join('')}[/tr]"
        row_num += 1
        new_row
      end
      "[table]#{rows.join('')}[/tbody][/table]"
    end
  rescue ArgumentError
    raise Error
  end

  def self.resolve_relative_urls(html, base_url)
    nodes = Nokogiri::HTML.fragment(html)
    nodes.traverse do |node|
      if node[:href]&.start_with?("/")
        node[:href] = base_url.chomp("/") + node[:href]
      end
    end
    nodes.to_s
  end
end
