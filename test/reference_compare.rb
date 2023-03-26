require "csv"
require "dtext/dtext"
require "yaml"

differences = []
CSV.open("dtext_reference.csv", "r").each do |row|
  input = row[0]
  color_expected = row[1]
  no_color_expected = row[2]

  color = DTextRagel.parse(input, allow_color: true)[0]
  no_color = DTextRagel.parse(input, allow_color: false)[0]
  if color != color_expected
    differences << [input, color_expected, color]
  end
  if no_color != no_color_expected
    differences << [input, no_color_expected, no_color]
  end
end

File.open("differences.yml", "w") { |f| f.write(YAML.dump(differences, line_width: 999_999_999)) }
