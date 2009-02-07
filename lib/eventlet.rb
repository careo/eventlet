require 'rubygems'
require 'eventmachine'


$:.unshift File.dirname(__FILE__)
begin
  require 'fiber'
rescue LoadError 
  require 'ext/fiber18'
end

require 'eventlet/channel'
module Eventlets
  
  class Eventlet
    @@fibers = {}
    
    def initialize(&block)
      @fiber = Fiber.new(&block)
      # FIXME: this is a SUPER nasty hack to be able to do Eventlet.current
      # by exploiting the existance of Fiber.current.
      # it probably will also leak memory like a sieve.
      @@fibers[@fiber] = self
    end

    # Create a new eventlet, or cooperative thread of control, within which
    # to execute the +&block+. The block will be scheduled to run in the 
    # next tick.
    def self.spawn(&block)
      e = self.new(&block)
      EM.next_tick {
        e.resume
      }
      e
    end

    # Create an eventlet and schedule it to be called after +duration+ seconds.
    def self.call_after(duration,&blk)
      e = self.new(&blk)
      EM.add_timer(duration) {
        e.resume
      }
      e
    end
    
    # Yield control to another eventlet until at least +duration+ seconds.
    # Calling sleep with a +duration+ of 0 or nil will put sleep the eventlet
    # until resumed elsewhere.
    def self.sleep(duration=nil)
      f = Fiber.current
      if duration && duration > 0
        EM.add_timer(duration) {
          f.resume
        }
      end
      Fiber.yield
    end

    # FIXME: this abuses a SUPER nasty hack to work. so ugly.
    def self.current
      @@fibers[Fiber.current] || nil
    end

    def alive?
      return true if @fiber.alive?
      false
    end

    # resumes a given eventlet immediately, passing control to it.
    def resume(*args)
      @fiber.resume(*args)
    end
  
  end #Eventlet

end #Eventlets
if $0 == __FILE__
  include Eventlets
  
  require 'ext/em/spec'
  
  EventMachine.describe "Eventlet" do
    it "should create new Eventlets that are alive" do
      eventlet = Eventlet.new { puts 1 }
      eventlet.should.be.alive?
      done
    end
  end

  EventMachine.describe "spawn" do
    it "should run things in order" do
      run_order = []
      run_order << :outer
      Eventlet.spawn do
        run_order << :inner
      end
      run_order << :outer
      EventMachine.add_timer(1) { 
        run_order.should == [:outer, :outer, :inner]
        done
      }
    end
  end

  EventMachine.describe "sleep" do
    it "should suspend and resume a duration " do
      start = Time.now
      e = Eventlet.spawn do
        Eventlet.sleep(0.1)
      end
      e.should.be.alive?
      EventMachine.next_tick { e.should.be.alive? }
      EventMachine.add_timer(0.2) { e.should.not.be.alive?; done}
    end

    it "should simply suspend the caller if not given a time " do
      start = Time.now
      e = Eventlet.spawn do
        Eventlet.sleep
      end
      e.should.be.alive?
      EventMachine.add_timer(0.5) { e.should.be.alive?; done }
    end
  end

  EventMachine.describe "call_after" do
    it "should come alive after the specified duration" do
      start_at = Time.now
      end_at = nil
      e = Eventlet.call_after(0.2) {
        end_at = Time.now
      }
      EventMachine.add_timer(0.5) {
        (end_at - start_at).should.be < 0.3
        done
      }
    end
  end

end
