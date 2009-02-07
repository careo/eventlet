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
    attr_reader :senders, :receivers
    
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
        EM.next_tick { receiver.resume(*msg) }
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
      @sender.should.be.alive?
      done
    end

    it "should resume after another eventlet receives" do
      @receiver = Eventlet.spawn do
        @channel.receive
      end
      EM.add_timer(0.1) {
        @sender.should.not.be.alive?
        done
      }
    end

    it "should have really sent the message to to the receiver" do
      @receiver = Eventlet.spawn do
        @message = @channel.receive
      end
      EM.add_timer(0.1) {
        @message.should == :foo
        done
      }
    end

  end
  
  EventMachine.describe "An Eventlet receiving on a Channel with no sender" do
    
    before do
      @channel = Channel.new
      @receiver = Eventlet.spawn do
        @message = @channel.receive
      end
    end
    
    it "should sleep" do
      @receiver.should.be.alive?
      done
    end
    
    it "should resume after another eventlet sends" do
      @sender = Eventlet.spawn do
        @channel.send(:foo)
      end
      @receiver.should.be.alive?
      @sender.should.be.alive?

      EM.add_timer(0.1) {
        @sender.should.not.be.alive?
        @receiver.should.not.be.alive?
        done
      }
    end

    it "should receive the message after another eventlet sends" do
      @sender = Eventlet.spawn do
        @channel.send(:foo)
      end

      EM.add_timer(0.1) {
        @message.should == :foo
        done
      }
    end
  
  end

  EventMachine.describe "A pair of eventlets taking turns playing ping-pong" do
    
    before do
      @channel = Channel.new
      @pinger = Eventlet.spawn do
        pings = [:ping_one, :ping_two, :ping_three, :pang]
        pings.each do |ping|
          @channel.send ping
          pong = @channel.receive
        end
      end
      @ponger = Eventlet.spawn do
        pongs = [:pong_one, :pong_two, :pong_three, :pang]
        pongs.each do |pong|
          ping = @channel.receive
          @channel.send pong
        end
      end
    end
    
    it "should exchange messages back and forth" do
      EM.add_timer(0.1) {
        # the only way I can think to test this is by just ensuring neither of the dudes is hung
        # waiting on the other.
        @pinger.should.not.be.alive?
        @ponger.should.not.be.alive?
        # and that the channel is clear
        @channel.senders.empty?.should == true
        @channel.receivers.empty?.should == true
        done
      }
    end
  end

  EventMachine.describe "A pair of eventlets both trying to ping before someone pongs" do
    
    before do
      @channel = Channel.new
      @pinger = Eventlet.spawn do
        pings = [:ping_one, :ping_two, :ping_three, :pang]
        pings.each do |ping|
          @channel.send ping
          pong = @channel.receive
        end
      end
      @ponger = Eventlet.spawn do
        pongs = [:pong_one, :pong_two, :pong_three, :pang]
        pongs.each do |pong|
          @channel.send pong
          ping = @channel.receive
        end
      end
    end
    
    it "should never end (aka: Dane hasn't added deadlock prevention)" do
      EM.add_timer(0.1) {
        # the only way I can think to test this is by just ensuring that both these
        # dudes are stuck waiting for something to happen
        @pinger.should.be.alive?
        @ponger.should.be.alive?
        # and the channel has two things stuck waiting
        @channel.senders.empty?.should == false
        @channel.receivers.empty?.should == true
        done
      }
    end
  end


end
