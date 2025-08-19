# frozen_string_literal: true

require_relative "lib/inception/version"

Gem::Specification.new do |spec|
  spec.name = "incepti0n"
  spec.version = Inception::VERSION
  spec.authors = ["Jonathan Siegel"]
  spec.email = ["<248302+usiegj00@users.noreply.github.com>"]

  spec.summary = "Interactive headless browser control with screencast streaming"
  spec.description = "A Ruby gem that provides Guacamole-like remote desktop functionality for headless Chrome/Chromium browsers using CDP and Ferrum"
  spec.homepage = "https://github.com/usiegj00/inception"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/usiegj00/inception"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ferrum", "~> 0.15"
  spec.add_dependency "faye-websocket", "~> 0.11"
  spec.add_dependency "sinatra", "~> 4.0"
  spec.add_dependency "puma", "~> 6.0"
  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "eventmachine", "~> 1.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
