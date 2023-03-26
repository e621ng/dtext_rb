require "csv"
require "dtext/dtext"

CSV.open("dtext_reference.csv", "w") do |result|
  CSV.foreach("dtext.csv") do |row|
    input = row.first
    no_color = DText.parse(input, allow_color: false)[0]
    color = DText.parse(input, allow_color: true)[0]
    result << [input, color, no_color]
  end
end
