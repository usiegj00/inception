# frozen_string_literal: true

require 'thor'

module Inception
  class CLI < Thor
    desc "serve", "Start the Inception server with browser control interface"
    option :port, type: :numeric, default: 8080, desc: "Port to run the server on"
    option :host, type: :string, default: '0.0.0.0', desc: "Host to bind the server to"
    def serve
      puts "🧠 Starting Inception - Remote Browser Control"
      puts "Port: #{options[:port]}"
      puts "Host: #{options[:host]}"
      puts ""
      puts "Open your browser to: http://localhost:#{options[:port]}"
      puts "Press Ctrl+C to stop"
      puts ""
      
      Server.set :port, options[:port]
      Server.set :bind, options[:host]
      Server.run_with_browser!
    end

    desc "version", "Show version"
    def version
      puts "Inception v#{Inception::VERSION}"
    end

    default_task :serve
  end
end