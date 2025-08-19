# frozen_string_literal: true

require_relative "inception/version"
require_relative "inception/browser"
require_relative "inception/screencast"
require_relative "inception/server"
require_relative "inception/cli"

module Inception
  class Error < StandardError; end
end
