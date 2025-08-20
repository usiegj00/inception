# frozen_string_literal: true

require 'base64'
require 'json'

module Inception
  class Screencast
    attr_reader :browser, :clients

    def initialize(browser)
      @browser = browser
      @clients = []
      @running = false
    end

    def start
      return if @running

      @running = true
      @browser.enable_screencast do |frame_data, session_id|
        broadcast_frame(frame_data, session_id)
      end
      
      @browser.enable_cursor_tracking do |cursor_type|
        broadcast_cursor(cursor_type)
      end
    end

    def stop
      return unless @running

      @running = false
      @browser.disable_screencast
    end

    def add_client(websocket)
      @clients << websocket
      send_initial_data(websocket)
    end

    def handle_input(data)
      case data['type']
      when 'click'
        @browser.click_at(data['x'], data['y'])
      when 'keypress'
        if data['key']
          @browser.key_press(data['key'])
        elsif data['text']
          @browser.type_text(data['text'])
        end
      when 'navigate'
        if data['url']
          puts "DEBUG: Attempting to navigate to: #{data['url']}"
          if data['url'].start_with?('chrome://')
            puts "WARNING: chrome:// URLs may not work in headless Chrome. Try switching to non-headless mode."
          end
          @browser.navigate_to(data['url'])
        end
      end
    rescue => e
      puts "Error handling input: #{e.message}"
    end

    private

    def broadcast_frame(frame_data, session_id = nil)
      return if @clients.empty?

      message = JSON.generate({
        type: 'frame',
        data: frame_data,
        sessionId: session_id,
        timestamp: Time.now.to_f
      })

      @clients.each do |client|
        begin
          client.send(message)
        rescue => e
          puts "Error sending frame to client: #{e.message}"
          @clients.delete(client)
        end
      end
    end

    def broadcast_cursor(cursor_type)
      return if @clients.empty?

      message = JSON.generate({
        type: 'cursor',
        cursor: cursor_type,
        timestamp: Time.now.to_f
      })

      @clients.each do |client|
        begin
          client.send(message)
        rescue => e
          puts "Error sending cursor to client: #{e.message}"
          @clients.delete(client)
        end
      end
    end

    def send_initial_data(websocket)
      begin
        page_info = @browser.get_page_info
        
        message = JSON.generate({
          type: 'init',
          pageInfo: page_info,
          timestamp: Time.now.to_f
        })

        websocket.send(message)
      rescue => e
        puts "Browser not ready yet, client will receive frames when available"
        # Don't send init message if browser isn't ready
        # Client will get frames once screencast starts
      end
    end
  end
end