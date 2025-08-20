# frozen_string_literal: true

require 'ferrum'
require 'base64'
require 'json'

module Inception
  class Browser
    attr_reader :browser, :page, :cdp_port

    def initialize(options = {})
      @options = default_options.merge(options)
      @browser = nil
      @page = nil
      @screencast_enabled = false
      @logger = options[:logger] || default_logger
      @cdp_port = nil
    end

    def start
      @logger.info "Starting browser with options: #{@options.inspect}"
      @browser = Ferrum::Browser.new(@options)
      @page = @browser.create_page
      @cdp_port = extract_cdp_port
      @logger.info "Browser started successfully"
      @logger.info "CDP endpoint available at: #{cdp_endpoint}" if @cdp_port
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

    def enable_cursor_tracking(&callback)
      ensure_started
      @cursor_callback = callback
      
      # Enable runtime for script injection
      @page.command('Runtime.enable')
      
      # Inject script to track cursor changes
      @page.evaluate(<<~JS)
        (function() {
          let lastCursor = null;
          
          function reportCursor(cursor) {
            if (cursor !== lastCursor) {
              lastCursor = cursor;
              window.reportCursorChange && window.reportCursorChange(cursor);
            }
          }
          
          // Track cursor on mouseover events
          document.addEventListener('mouseover', function(e) {
            const computedStyle = window.getComputedStyle(e.target);
            reportCursor(computedStyle.cursor);
          });
          
          // Also check on mousemove for dynamic cursor changes
          let mouseMoveTimeout;
          document.addEventListener('mousemove', function(e) {
            clearTimeout(mouseMoveTimeout);
            mouseMoveTimeout = setTimeout(() => {
              const computedStyle = window.getComputedStyle(e.target);
              reportCursor(computedStyle.cursor);
            }, 50);
          });
          
          // Report initial cursor
          reportCursor(window.getComputedStyle(document.body).cursor);
        })();
      JS
      
      # Set up callback for cursor reports
      @page.evaluate(<<~JS)
        window.reportCursorChange = function(cursor) {
          fetch('data:text/plain;charset=utf-8,' + encodeURIComponent('CURSOR:' + cursor))
            .catch(() => {}); // Ignore errors, we'll handle via other means
        };
      JS
      
      # Alternative: use console API to capture cursor changes
      @page.command('Runtime.addBinding', name: 'reportCursorChange')
      @page.on('Runtime.bindingCalled') do |params|
        if params['name'] == 'reportCursorChange' && @cursor_callback
          cursor_type = params['payload']
          @cursor_callback.call(cursor_type)
        end
      end
      
      # Update the cursor reporting to use the binding
      @page.evaluate(<<~JS)
        window.reportCursorChange = function(cursor) {
          reportCursorChange(cursor);
        };
      JS
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

    def cdp_endpoint
      return nil unless @cdp_port
      "ws://127.0.0.1:#{@cdp_port}"
    end

    def cdp_http_endpoint  
      return nil unless @cdp_port
      "http://127.0.0.1:#{@cdp_port}"
    end

    def mcp_chrome_config
      return nil unless @cdp_port
      {
        message: "Configure mcp-chrome to connect to inception-serve browser:",
        instructions: [
          "1. The Chrome browser is already running with CDP enabled",
          "2. mcp-chrome needs to connect to this CDP endpoint instead of launching its own browser",
          "3. This requires modifying mcp-chrome to accept external CDP connections"
        ],
        cdp_endpoint: cdp_endpoint,
        cdp_http_endpoint: cdp_http_endpoint,
        port: @cdp_port,
        note: "Currently mcp-chrome only works with Chrome extension. Direct CDP connection requires modification."
      }
    end

    private

    def ensure_started
      raise Error, "Browser not started. Call #start first." unless @browser && @page
    end

    def extract_cdp_port
      return nil unless @browser
      
      # Get the CDP port from Ferrum browser instance
      if @browser.respond_to?(:process) && @browser.process&.port
        @browser.process.port
      elsif @browser.respond_to?(:port)
        @browser.port  
      else
        # Try to extract from browser options or command line
        @options.dig(:browser_options, 'remote-debugging-port') || 9222
      end
    rescue => e
      @logger.warn "Could not extract CDP port: #{e.message}"
      nil
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