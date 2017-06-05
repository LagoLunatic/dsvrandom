
DEBUG = true

require 'Qt'
require 'fileutils'
require 'yaml'

require_relative '../dsvlib'

require_relative 'version'

require_relative 'randomizer_window'

if defined?(Ocra)
  exit
end

Dir.chdir(File.expand_path("..", File.dirname(__FILE__)))

$qApp = Qt::Application.new(ARGV)
window = RandomizerWindow.new
$qApp.exec
