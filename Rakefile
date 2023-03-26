# ENV["G_MESSAGES_DEBUG"] = "all"

begin
  require "rake/extensiontask"
  require "rubygems/package_task"
  require "bundler"

  Bundler.setup(:default, :development)
rescue LoadError, Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit 1
end

Rake::ExtensionTask.new "dtext" do |ext|
  # this goes here to ensure ragel runs *before* the extension is compiled.
  task :compile => ["ext/dtext/dtext.c", "ext/dtext/rb_dtext.c"]
  ext.lib_dir = "lib/dtext"
end

CLOBBER.include %w(ext/dtext/dtext.c dtext_rb.gemspec)
CLEAN.include %w(lib/dtext bin/cdtext.exe)

task compile: "bin/cdtext.exe"
file "bin/cdtext.exe" => "ext/dtext/dtext.c" do
  flags = "#{ENV["CFLAGS"] || "-ggdb3 -pg -Wall -Wno-unused-const-variable"}"
  libs = "$(pkg-config --cflags --libs glib-2.0)"
  sh "gcc -DCDTEXT -o bin/cdtext.exe ext/dtext/dtext.c #{flags} #{libs}"
end

file "ext/dtext/dtext.c" => Dir["ext/dtext/dtext.{rl,h}", "Rakefile"] do
  sh "ragel -G1 -C ext/dtext/dtext.rl -o ext/dtext/dtext.c"
end

def run_dtext(*args)
  ruby "-Ilib", "-rdtext", *args
end

task test_inline_ragel: :compile do
  Bundler.with_unbundled_env do
    run_dtext "-e", 'puts DText.parse("hello\r\nworld")'
  end
end

task test: :compile do
  Bundler.with_unbundled_env do
    run_dtext "test/dtext_test.rb" #, '--name=test_strip'
  end
end

task reference_compare: :compile do
  Bundler.with_unbundled_env do
    run_dtext "test/reference_compare.rb"
  end
end

task reference_generate: :compile do
  Bundler.with_unbundled_env do
    run_dtext "test/reference_generate.rb"
  end
end

task default: :test
