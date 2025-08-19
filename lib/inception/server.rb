# frozen_string_literal: true

require 'sinatra/base'
require 'faye/websocket'
require 'eventmachine'
require 'json'

module Inception
  class Server < Sinatra::Base
    set :port, 8080
    set :bind, '0.0.0.0'
    set :server, 'puma'
    set :public_folder, File.join(File.dirname(__FILE__), '..', '..', 'public')
    

    get '/' do
      erb :index
    end

    get '/websocket' do
      if Faye::WebSocket.websocket?(request.env)
        ws = Faye::WebSocket.new(request.env)
        
        ws.on :open do |event|
          puts "WebSocket client connected"
          Server.get_screencast&.add_client(ws)
        end
        
        ws.on :message do |event|
          begin
            data = JSON.parse(event.data)
            Server.get_screencast&.handle_input(data)
          rescue JSON::ParserError => e
            puts "Invalid JSON received: #{e.message}"
          end
        end
        
        ws.on :close do |event|
          puts "WebSocket client disconnected"
          Server.get_screencast&.clients&.delete(ws)
        end
        
        ws.rack_response
      else
        [400, {}, ['Not a WebSocket request']]
      end
    end

    def self.run_with_browser!
      @@browser = Browser.new
      @@screencast = nil
      
      Signal.trap('INT') do
        puts "\nShutting down..."
        @@screencast&.stop
        @@browser&.stop
        EM.stop if EM.reactor_running?
        exit
      end
      
      Signal.trap('TERM') do
        puts "\nShutting down..."
        @@screencast&.stop
        @@browser&.stop
        EM.stop if EM.reactor_running?
        exit
      end
      
      Thread.new do
        sleep 2
        begin
          @@browser.start
          @@screencast = Screencast.new(@@browser)
          @@screencast.start
          @@browser.navigate_to('https://duckduckgo.com')
          puts "Browser started and navigated to DuckDuckGo"
        rescue => e
          puts "Error starting browser: #{e.message}"
        end
      end
      
      puts "Starting Inception server on http://localhost:#{port}"
      run!
    end

    def self.get_browser
      @@browser
    end

    def self.get_screencast
      @@screencast
    end

    private

    def erb(template)
      case template
      when :index
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
              <title>Inception - Remote Browser Control</title>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style>
                  * {
                      margin: 0;
                      padding: 0;
                      box-sizing: border-box;
                  }
                  
                  body {
                      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                      background: #1a1a1a;
                      color: #fff;
                      overflow: hidden;
                  }
                  
                  .container {
                      display: flex;
                      flex-direction: column;
                      height: 100vh;
                  }
                  
                  .header {
                      background: #2d2d2d;
                      padding: 10px 20px;
                      border-bottom: 1px solid #404040;
                      display: flex;
                      align-items: center;
                      justify-content: space-between;
                  }
                  
                  .header h1 {
                      font-size: 18px;
                      font-weight: 600;
                  }
                  
                  .status {
                      display: flex;
                      align-items: center;
                      gap: 10px;
                  }
                  
                  .status-indicator {
                      width: 8px;
                      height: 8px;
                      border-radius: 50%;
                      background: #ef4444;
                  }
                  
                  .status-indicator.connected {
                      background: #22c55e;
                  }
                  
                  .browser-container {
                      flex: 1;
                      position: relative;
                      background: #000;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                  }
                  
                  .browser-screen {
                      max-width: 100%;
                      max-height: 100%;
                      border: 1px solid #404040;
                      cursor: crosshair;
                      image-rendering: -webkit-optimize-contrast;
                      image-rendering: crisp-edges;
                  }
                  
                  
                  .browser-screen.connected {
                      cursor: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M2 2L14 14M2 14L14 2" stroke="green" stroke-width="2" fill="none"/></svg>') 8 8, crosshair;
                  }
                  
                  .browser-screen.disconnected {
                      cursor: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M2 2L14 14M2 14L14 2" stroke="red" stroke-width="2" fill="none"/></svg>') 8 8, crosshair;
                  }
                  
                  .loading {
                      text-align: center;
                      color: #888;
                  }
                  
                  .controls {
                      background: #2d2d2d;
                      padding: 10px 20px;
                      border-top: 1px solid #404040;
                      display: flex;
                      gap: 10px;
                      align-items: center;
                  }
                  
                  .url-input {
                      flex: 1;
                      background: #1a1a1a;
                      border: 1px solid #404040;
                      color: #fff;
                      padding: 8px 12px;
                      border-radius: 4px;
                      font-size: 14px;
                  }
                  
                  .url-input:focus {
                      outline: none;
                      border-color: #0ea5e9;
                  }
                  
                  .btn {
                      background: #0ea5e9;
                      color: #fff;
                      border: none;
                      padding: 8px 16px;
                      border-radius: 4px;
                      cursor: pointer;
                      font-size: 14px;
                  }
                  
                  .btn:hover {
                      background: #0284c7;
                  }
              </style>
          </head>
          <body>
              <div class="container">
                  <div class="header">
                      <h1>🧠 Inception - Remote Browser Control</h1>
                      <div class="status">
                          <div class="status-indicator" id="status-indicator"></div>
                          <span id="status-text">Disconnected</span>
                      </div>
                  </div>
                  
                  <div class="browser-container">
                      <div class="loading" id="loading">
                          <h2>Connecting to browser...</h2>
                          <p>Please wait while we establish connection</p>
                      </div>
                      <img class="browser-screen" id="browser-screen" style="display: none;" />
                  </div>
                  
                  <div class="controls">
                      <input type="text" class="url-input" id="url-input" placeholder="Enter URL to navigate..." />
                      <button class="btn" id="navigate-btn">Go</button>
                      <button class="btn" id="refresh-btn">Refresh</button>
                  </div>
              </div>
              
              <script>
                  class InceptionClient {
                      constructor() {
                          this.ws = null;
                          this.connected = false;
                          this.screen = document.getElementById('browser-screen');
                          this.loading = document.getElementById('loading');
                          this.statusIndicator = document.getElementById('status-indicator');
                          this.statusText = document.getElementById('status-text');
                          this.urlInput = document.getElementById('url-input');
                          this.navigateBtn = document.getElementById('navigate-btn');
                          this.refreshBtn = document.getElementById('refresh-btn');
                          
                          this.setupEventListeners();
                          this.connect();
                      }
                      
                      connect() {
                          const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                          const wsUrl = `${protocol}//${window.location.host}/websocket`;
                          
                          this.ws = new WebSocket(wsUrl);
                          
                          this.ws.onopen = () => {
                              this.connected = true;
                              this.updateStatus('Connected', true);
                          };
                          
                          this.ws.onmessage = (event) => {
                              const data = JSON.parse(event.data);
                              this.handleMessage(data);
                          };
                          
                          this.ws.onclose = () => {
                              this.connected = false;
                              this.updateStatus('Disconnected', false);
                              setTimeout(() => this.connect(), 3000);
                          };
                          
                          this.ws.onerror = (error) => {
                              console.error('WebSocket error:', error);
                              this.updateStatus('Error', false);
                          };
                      }
                      
                      handleMessage(data) {
                          switch (data.type) {
                              case 'init':
                                  this.loading.style.display = 'none';
                                  this.screen.style.display = 'block';
                                  this.urlInput.value = data.pageInfo.url || '';
                                  break;
                                  
                              case 'frame':
                                  this.screen.src = `data:image/png;base64,${data.data}`;
                                  break;
                          }
                      }
                      
                      setupEventListeners() {
                          this.screen.addEventListener('click', (e) => {
                              if (!this.connected) return;
                              
                              const rect = this.screen.getBoundingClientRect();
                              const scaleX = this.screen.naturalWidth / rect.width;
                              const scaleY = this.screen.naturalHeight / rect.height;
                              
                              const x = (e.clientX - rect.left) * scaleX;
                              const y = (e.clientY - rect.top) * scaleY;
                              
                              this.sendInput({
                                  type: 'click',
                                  x: Math.round(x),
                                  y: Math.round(y)
                              });
                          });
                          
                          document.addEventListener('keydown', (e) => {
                              if (!this.connected || document.activeElement === this.urlInput) return;
                              
                              e.preventDefault();
                              
                              
                              // Handle special keys
                              if (e.key === 'Enter' || e.key === 'Backspace' || e.key === 'Tab' || e.key === 'Escape' || e.key === 'ArrowUp' || e.key === 'ArrowDown' || e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
                                  this.sendInput({
                                      type: 'keypress',
                                      key: e.key
                                  });
                              } else if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
                                  // Handle printable characters
                                  this.sendInput({
                                      type: 'keypress',
                                      text: e.key
                                  });
                              }
                          });
                          
                          this.navigateBtn.addEventListener('click', () => {
                              const url = this.urlInput.value.trim();
                              if (url && this.connected) {
                                  this.sendInput({
                                      type: 'navigate',
                                      url: url.startsWith('http') ? url : `https://${url}`
                                  });
                              }
                          });
                          
                          this.urlInput.addEventListener('keypress', (e) => {
                              if (e.key === 'Enter') {
                                  this.navigateBtn.click();
                              }
                          });
                          
                          this.refreshBtn.addEventListener('click', () => {
                              if (this.connected && this.urlInput.value) {
                                  this.sendInput({
                                      type: 'navigate',
                                      url: this.urlInput.value
                                  });
                              }
                          });
                      }
                      
                      sendInput(data) {
                          if (this.connected && this.ws.readyState === WebSocket.OPEN) {
                              this.ws.send(JSON.stringify(data));
                          }
                      }
                      
                      updateStatus(text, connected) {
                          this.statusText.textContent = text;
                          this.statusIndicator.classList.toggle('connected', connected);
                          this.screen.classList.toggle('connected', connected);
                          this.screen.classList.toggle('disconnected', !connected);
                      }
                  }
                  
                  new InceptionClient();
              </script>
          </body>
          </html>
        HTML
      end
    end
  end
end