# frozen_string_literal: true

require 'ferrum'
require 'base64'
require 'json'

module Inception
  class Browser
    attr_reader :browser, :page

    def initialize(options = {})
      @options = default_options.merge(options)
      @browser = nil
      @page = nil
      @screencast_enabled = false
      @logger = options[:logger] || default_logger
    end

    def start
      @logger.info "Starting browser with options: #{@options.inspect}"
      @browser = Ferrum::Browser.new(@options)
      @page = @browser.create_page
      @logger.info "Browser started successfully"
      @browser
    rescue => e
      @logger.error "Failed to start browser: #{e.message}"
      raise Error, "Failed to start browser: #{e.message}"
    end

    def stop
      @browser&.quit
      @browser = nil
      @page = nil
    end

    def navigate_to(url)
      ensure_started
      @page.go_to(url)
    end

    def click_at(x, y)
      ensure_started
      @page.mouse.click(x: x, y: y)
    end

    def type_text(text)
      ensure_started
      @page.keyboard.type(text)
    end

    def key_press(key)
      ensure_started
      @logger.info "Pressing key: #{key}"
      
      # Use Ferrum's keyboard methods - try down/up combination
      case key
      when 'Enter'
        @page.keyboard.down(:enter)
        @page.keyboard.up(:enter)
      when 'Backspace'
        @page.keyboard.down(:backspace)
        @page.keyboard.up(:backspace)
      when 'Tab'
        @page.keyboard.down(:tab)
        @page.keyboard.up(:tab)
      when 'Escape'
        @page.keyboard.down(:escape)
        @page.keyboard.up(:escape)
      when 'ArrowUp'
        @page.keyboard.down(:arrow_up)
        @page.keyboard.up(:arrow_up)
      when 'ArrowDown'
        @page.keyboard.down(:arrow_down)
        @page.keyboard.up(:arrow_down)
      when 'ArrowLeft'
        @page.keyboard.down(:arrow_left)
        @page.keyboard.up(:arrow_left)
      when 'ArrowRight'
        @page.keyboard.down(:arrow_right)
        @page.keyboard.up(:arrow_right)
      else
        @page.keyboard.type(key)
      end
    rescue => e
      @logger.error "Failed to press key #{key}: #{e.message}"
      raise
    end

    def take_screenshot
      ensure_started
      @page.screenshot(encoding: :base64, format: 'png')
    end

    def enable_screencast(&callback)
      ensure_started
      @screencast_enabled = true
      @screencast_callback = callback
      
      @page.command('Page.startScreencast', format: 'png', quality: 80, maxWidth: 1280, maxHeight: 720, everyNthFrame: 1)
      
      @page.on('Page.screencastFrame') do |params|
        if @screencast_callback && @screencast_enabled
          @screencast_callback.call(params['data'], params['sessionId'])
          @page.command('Page.screencastFrameAck', sessionId: params['sessionId'])
        end
      end
    end

    def disable_screencast
      return unless @screencast_enabled
      
      @screencast_enabled = false
      @page.command('Page.stopScreencast')
      @screencast_callback = nil
    end

    def get_page_info
      ensure_started
      {
        title: @page.title,
        url: @page.current_url,
        viewport: {
          width: @page.evaluate("window.innerWidth"),
          height: @page.evaluate("window.innerHeight")
        }
      }
    end

    private

    def ensure_started
      raise Error, "Browser not started. Call #start first." unless @browser && @page
    end

    def default_options
      {
        headless: true,
        window_size: [1280, 720],
        browser_options: {
          'no-sandbox': nil,
          'disable-dev-shm-usage': nil,
          'disable-gpu': nil,
          'disable-web-security': nil,
          'allow-running-insecure-content': nil,
          'remote-debugging-port': 0
        }
      }
    end

    def default_logger
      require 'logger'
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      end
      logger
    end
  end
end