# 🧠 Inception

A Ruby gem that provides Guacamole-like remote desktop functionality for headless Chrome/Chromium browsers using CDP (Chrome DevTools Protocol) and Ferrum. Control a headless browser through a web interface with real-time screen streaming.

## Features

- 🌐 **Remote Browser Control**: Control a headless Chrome browser through a web interface
- 📺 **Real-time Screencast**: Live streaming of browser screen using WebSockets
- 🖱️ **Interactive Input**: Mouse clicks and keyboard input forwarded to the browser
- 🚀 **Easy Setup**: Simple CLI command to start the server
- 🔧 **Built on Ferrum**: Leverages the powerful Ferrum gem for Chrome automation

## Installation

Install the gem by executing:

```bash
gem install inception
```

## Usage

Start the Inception server:

```bash
inception serve
```

This will:
1. Start a headless Chrome browser
2. Launch a web server on `http://localhost:8080`  
3. Navigate the browser to DuckDuckGo.com
4. Stream the browser screen to your web interface

Open your browser to `http://localhost:8080` and you'll see the remote browser screen. You can:

- **Click** anywhere on the screen to interact with the page
- **Type** using your keyboard (when the web interface has focus)  
- **Navigate** to new URLs using the address bar
- **Refresh** the current page

### Command Options

```bash
inception serve --port 3000 --host 127.0.0.1
```

- `--port`: Port to run the server on (default: 8080)
- `--host`: Host to bind the server to (default: 0.0.0.0)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/inception. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/inception/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Inception project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/inception/blob/master/CODE_OF_CONDUCT.md).
