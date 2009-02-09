require File.dirname(__FILE__) + "/../eventlet"
 
module Eventlets
  
  # Used to send one event from one coroutine to many others. Has a "send" and
  # a "wait" method. Sending more than once is not allowed and will cause an
  # exception; waiting more than once is allowed and will always produce the
  # same value.
  # An abstraction where an arbitrary number of coroutines
  # can wait for one event from another.
  # 
  # Events differ from channels in two ways:
  #   1) calling send() does not unschedule the current coroutine
  #   2) send() can only be called once; use reset() to prepare the event for 
  #      another send()
  # They are ideal for communicating return values between coroutines.
  class Event
    
    def initialize
      @waiters = []
    end
    
    # Reset this event so it can be used to send again.
    # Can only be called after send has been called.
    def reset
      if defined? @result
        remove_instance_variable :@result
      else
        raise RuntimeError, "Tried to reset an unused event"
      end
      @waiters = []
    end
    
    # Return true if the wait() call will return immediately. 
    # Used to avoid waiting for things that might take a while to time out.
    # For example, you can put a bunch of events into a list, and then visit
    # them all repeatedly, calling ready() until one returns True, and then
    # you can wait() on that one."""
    def ready?
      !!defined? @result
    end
    
    # Wait until another coroutine calls send.
    # Returns the value the other coroutine passed to
    # send.
    def wait
      if defined? @result
        return @result
      else
        @waiters << Eventlet.current
        Eventlet.sleep
      end
    end
        
    def send *args
      if defined? @result
        raise RuntimeError, "Tried calling #send on an event that had been used already"
      end
      @result = *args
      @waiters.each do |waiter|
        EM.next_tick {
          waiter.resume @result
        }
      end
    end

  end # Event
end # Eventlets


if $0 == __FILE__
  include Eventlets
  
  require 'ext/em/spec'

  EventMachine.describe "A new event" do
    before do
      @event = Event.new
    end
    
    it "should not be ready" do
      @event.should.not.be.ready?
      done
    end
   
    it "should block on wait" do
      e = Eventlet.spawn do
        @event.wait
      end
      EM.add_timer(0.1 ) {
        e.should.be.alive?
        done
      }
    end
    
    it "should not block on send" do
      e = Eventlet.spawn do
        @event.send
      end
      EM.next_tick {
        e.should.not.be.alive?
        done
      }
    end
    
  end

  EventMachine.describe "Waiting on an event" do
    before do
      @event = Event.new
    end
    
    it "should return the value passed to send for one waiter" do
      value = nil
      waiter = Eventlet.spawn do
        @event.wait.should == :done
        done
      end
      sender = Eventlet.spawn do
        @event.send :done
      end
    end

    it "should return same value to multiple waiters" do
      5.times do 
        Eventlet.spawn do
          @event.wait.should == :all_done
        end
      end
      Eventlet.spawn do
        @event.send :all_done
      end
      EM.add_timer(0.1) do
        done
      end
    end

    it "should return the same value when called from the same waiter" do
      Eventlet.spawn do
        5.times do
          @event.wait.should == :still_done
        end
        done
      end
      Eventlet.spawn do
        @event.send :still_done
      end
    end
    
  end

  EventMachine.describe "Sending an event" do
    before do
      @event = Event.new
    end
   
    it "twice should fail" do
      Eventlet.spawn do
        @event.send :one
      end
      Eventlet.spawn do
        proc{@event.send :two}.should.raise?
        done
      end
    end

  end

  EventMachine.describe "Resetting an event" do
    before do
      @event = Event.new
    end
    
    it "that has not been sent should raise an error" do
      Eventlet.spawn do
        proc {@event.reset}.should.raise?
        done
      end
    end

    it "that has been sent should permit sending again" do
      Eventlet.spawn do
        @event.send :one
        @event.reset
        proc {@event.send :two}.should.not.raise?
        done
      end
    end

  end

end