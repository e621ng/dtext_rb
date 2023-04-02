require "dtext/dtext"
require "json"
require "yaml"
require "zlib"

differences = []

Zlib::GzipReader.open("dtext_reference.json.gz") do |file|
  file.each_line.with_index do |line, i|
    puts i if i % 10_000 == 0
    json = JSON.parse(line)

    allow_color = %w(wp ua ui).include?(json["id"][0..1])
    dtext = DText.parse(json["i"], allow_color: allow_color)[0]
    if dtext != json["o"]
      differences << [json["id"], json["i"], json["o"], dtext]
    end
  end
end

File.open("differences.yml", "w") { |f| f.write(YAML.dump(differences, line_width: 999_999_999)) }
