require File.dirname(__FILE__) + "/../eventlet"

module Eventlets

  # A channel is a control flow primitive for co-routines. It is a 
  # "thread-like" queue for controlling flow between two (or more) co-routines.
  # The state model is:
  # 
  # * If one co-routine calls send(), it is unscheduled until another 
  #   co-routine calls receive().
  # * If one co-rounte calls receive(), it is unscheduled until another 
  #   co-routine calls send().
  # * Once a paired send()/receive() have been called, both co-routeines
  #   are rescheduled.
  # 
  # This is similar to: http://stackless.com/wiki/Channels
  class Channel
    
    def initialize
      @senders = []
      @receivers = []
    end
    
    def send(*msg)
      if @receivers.empty?
        @senders.push [Eventlet.current,*msg]
        Eventlet.sleep
      else
        receiver = @receivers.pop
        receiver.resume(*msg)
      end
    end
    
    def receive
      if @senders.empty?
        @receivers << Eventlet.current
        Eventlet.sleep
      else
        sender, message = @senders.pop
        EM.next_tick { sender.resume }
        return message
      end
    end

  end # Channel
end # Eventlet

if $0 == __FILE__
  include Eventlets
  require 'ext/em/spec'
  
  EventMachine.describe "An Eventlet sending on a Channel with no receiver" do
    
    before do
      @channel = Channel.new
      @sender = Eventlet.spawn do
        @channel.send(:foo)
      end
    end
    
    it "should sleep" do
      @sender.alive?.should == true
      done
    end

    it "should resume after another eventlet receives" do
      @receiver = Eventlet.spawn do
        puts @channel.receive
      end
      EM.add_timer(0.2) {
        @sender.alive?.should == false
        done
      }
    end

  end
  
  EventMachine.describe "An Eventlet receiving on a Channel with no sender" do
    
    before do
      @channel = Channel.new
      @receiver = Eventlet.spawn do
        puts @channel.receive
      end
    end
    
    #it "should sleep" do
    #  @receiver.alive?.should == true
    #  done
    #end
    
    it "should resume after another eventlet sends" do
      @sender = Eventlet.spawn do
        @channel.send(1)
      end
      @sender.alive?.should == true
      @receiver.alive?.should == false
      EM.add_timer(0.2) {
        @sender.alive?.should == true
        done
      }
    end
    
  
  end

  #EventMachine.describe "An Eventlet sending on a Channel with a receiver" do
  #
  #  it "should immediately pass control to the receiver" do
  #  end
  #  
  #  it "should regain control when the receiver finishes" do
  #  end
  #
  #end
  #
  #
  #  If one co-routine calls send(), it is unscheduled until another 
  #  #   co-routine calls receive().
  #
  #  it "should "
  #
  #
  #end
  
  
end
