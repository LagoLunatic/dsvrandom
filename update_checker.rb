
require 'net/http'
require 'json'

LATEST_RELEASE_DOWNLOAD_PAGE_URL = "https://github.com/LagoLunatic/dsvrandom/releases/latest"
LATEST_RELEASE_API_URL = "https://api.github.com/repos/lagolunatic/dsvrandom/releases/latest"

def check_for_updates
  response = Net::HTTP.get_response(URI(LATEST_RELEASE_API_URL))
  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    
    latest_version_name = data["tag_name"]
    if latest_version_name[0] == "v"
      latest_version_name = latest_version_name[1..-1]
    end
    
    if DSVRANDOM_VERSION.include?("-BETA")
      version_without_beta = DSVRANDOM_VERSION.split("-BETA")[0]
      if Gem::Version.new(latest_version_name) >= Gem::Version.new(version_without_beta)
        return latest_version_name
      else
        return nil
      end
    else
      if Gem::Version.new(latest_version_name) > Gem::Version.new(DSVRANDOM_VERSION)
        return latest_version_name
      else
        return nil
      end
    end
  else
    puts "Unexpected response when checking for updates.\nCode: #{response.code}, message: #{response.message}"
    return :error
  end
rescue StandardError => e
  error_message = "Error when checking for updates:\n#{e.message}\n\n#{e.backtrace.join("\n")}"
  puts error_message
  return :error
end
