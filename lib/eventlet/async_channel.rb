require File.dirname(__FILE__) + "/../eventlet"

module Eventlets

  # This is similar to a Channel, except that sending is asynchronous.
  class AsyncChannel

    def initialize
      # TODO: investigate using a deque and balance here instead of two
      # arrays. Everyone else does, so why shouldn't I?
      @queue = []
      @receivers = []
    end

    # Forwards +msg+ to the first waiting receiver
    def send(*msg)
      if @receivers.empty?
        @queue << msg
      else
        receiver = @receivers.shift
        EM.next_tick { receiver.resume(*msg) }
      end
    end

    def receive
      if @queue.empty?
        @receivers << Eventlet.current
        Eventlet.sleep
      else
        msg = @queue.shift
        return *msg
      end
    end

  end # Channel
end # Eventlet

if $0 == __FILE__
  include Eventlets
  require 'ext/em/spec'

  EventMachine.describe "An Eventlet sending on a Channel with no receiver" do

    before do
      @channel = AsyncChannel.new
      @sender = Eventlet.spawn do
        @channel.send(:foo)
      end
    end

    it "should not sleep" do
      EM.next_tick {
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
      @channel = AsyncChannel.new
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
      EM.next_tick {
        @receiver.should.be.alive?
        @sender.should.not.be.alive?
      }

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
      @channel = AsyncChannel.new
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
  
    it "should end with the first eventlet talking to itself, and the second blocking forever" do
      EM.add_timer(0.1) {
        # the only way I can think to test this is by just ensuring neither of the dudes is hung
        # waiting on the other.
        @pinger.should.not.be.alive?
        @ponger.should.be.alive?
        done
      }
    end
  end

  EventMachine.describe "A pair of eventlets both trying to ping before someone pongs" do

    before do
      @channel = AsyncChannel.new
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

    it "should not deadlock" do
      EM.add_timer(0.1) {
        # the only way I can think to test this is by just ensuring that both these
        # dudes managed to get their messages off
        @pinger.should.not.be.alive?
        @ponger.should.not.be.alive?
        done
      }
    end
  end

  EventMachine.describe "Multiple senders with one receiver" do 

    before do
      @channel = AsyncChannel.new
      [:one,:two,:three].each do |i|
        Eventlet.spawn do
          @channel.send i
        end
      end
    end

    it "should give the receiver both values in order" do
      Eventlet.spawn do
        @channel.receive.should == :one
        @channel.receive.should == :two
        @channel.receive.should == :three
        done
      end
    end

  end

  EventMachine.describe "Multiple receivers with one sender" do 

    before do
      @channel = AsyncChannel.new
    end

    it "should have a test with a better name" do
      Eventlet.spawn do
        @channel.send :one
        @channel.send :two
        @channel.send :three
      end
      Eventlet.spawn do 
        @channel.receive.should == :one
      end
      Eventlet.spawn do
        @channel.receive.should == :two
      end
      Eventlet.spawn do
        @channel.receive.should == :three
        done
      end
    end

  end

end
