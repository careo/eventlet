require File.dirname(__FILE__) + "/../eventlet"


module Eventlet
  module API
    
    # spawn(function, *args, **keyword)
    #   Create a new coroutine, or cooperative thread of control, within which
    #   to execute function. The function will be called with the given args 
    #   and keyword arguments and will remain in control unless it cooperatively
    #   yields by calling a socket method or sleep. spawn returns control to the
    #   caller immediately, and function will be called in a future main loop 
    #   iteration.
    def spawn(&blk)
      f = Fiber.new {
        blk.call
      }
      EM.next_tick {
        f.resume
      }
      f
    end
  
    # sleep(time)
    #   Yield control to another eligible coroutine until at least time seconds
    #   have elapsed. time may be specified as an integer, or a float if
    #   fractional seconds are desired. Calling sleep with a time of 0 is the
    #   canonical way of expressing a cooperative yield. For example, if one
    #   is looping over a large list performing an expensive calculation without
    #   calling any socket methods, it’s a good idea to call sleep(0)
    #   occasionally; otherwise nothing else will run.
    def sleep(time)
      c = Fiber.current
      EM.add_timer(time) {
        c.resume
      }
      Fiber.yield
    end

    # call_after(time, function, *args, **keyword)
    #   Schedule function to be called after time seconds have elapsed. time 
    #   may be specified as an integer, or a float if fractional seconds are
    #   desired. The function will be called with the given args and keyword
    #   arguments, and will be executed within the main loop’s coroutine.
    def call_after(time,&blk)
      f = Fiber.new {
        blk.call
      }
      EM.add_timer(time) {
        f.resume
      }
    end
    
  end #API
end #Eventlet

if $0 == __FILE__
  include Eventlet::API
  require 'ext/em/spec'
  
  EventMachine.describe "spawn" do
    it "should run things in order" do
      run_order = []
      Fiber.new {
        run_order << :outer
        inner = spawn do
          run_order << :inner
        end
        run_order << :outer
      }.resume
      EventMachine.add_timer(1) { 
        run_order.should == [:outer, :outer, :inner]
        done
      }
    end
  end

  EventMachine.describe "sleep" do
    it "should suspend the caller for a bit" do
      start = Time.now
      f = Fiber.new {
        sleep(1)
      }
      f.resume
      f.alive?.should == true
      EventMachine.add_timer(0.5) { f.alive?.should == true }
      EventMachine.add_timer(2) { f.alive?.should == false; done}
    end
  end

  #EventMachine.describe "call_after" do
  #  it "should call the block after the specified time" do
  #    Fiber.new {
  #      start_at = Time.now
  #      end_at = nil
  #      call_after(1) {
  #        end_at = Time.now
  #      }
  #      EventMachine.add_timer(1.5) {
  #        (end_at - start_at).should < 1
  #        done
  #      }
  #    }.resume
  #  end
  #
  #end
  
end