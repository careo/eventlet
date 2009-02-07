require 'rubygems'
require 'eventmachine'

$:.unshift File.dirname(__FILE__)
begin
  require 'fiber'
rescue LoadError 
  require 'ext/fiber18'
end

require 'eventlet/api'

