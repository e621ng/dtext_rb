require "dtext/dtext"
require "json"
require "zlib"

Zlib::GzipWriter.open("dtext_reference.json.gz") do |output|
  Zlib::GzipReader.open("dtext.json.gz") do |file|
    file.each_line.with_index do |line, i|
      puts i if i % 10_000 == 0
      json = JSON.parse(line)

      allow_color = %w(wp ua ui).include?(json["id"][0..1])
      dtext = DText.parse(json["body"], allow_color: allow_color)[0]

      output.puts({ id: json["id"], i: json["body"], o: dtext }.to_json + "\n")
    end
  end
end
