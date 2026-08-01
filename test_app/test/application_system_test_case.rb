require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["CI"]
    require "socket"

    driven_by :selenium, using: :chrome, screen_size: [1400, 1400],
      options: {
        browser: :remote,
        url: ENV.fetch("SELENIUM_REMOTE_URL", "http://localhost:4444/wd/hub")
      } do |options|
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--no-sandbox")
      options.add_argument("--headless=new")
    end

    host = ENV["CAPYBARA_APP_HOST"] ||
           IPSocket.getaddress(Socket.gethostname)
    Capybara.server_host = "0.0.0.0"
    Capybara.app_host = "http://#{host}"
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--no-sandbox")
    end
  end

  teardown do
    next if passed?
    logs = page.driver.browser.logs.get(:browser)
    if logs.any?
      puts "\n--- Browser console logs ---"
      logs.each { |log| puts "  [#{log.level}] #{log.message}" }
    end
  end
end
