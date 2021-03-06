#!/bin/env ruby

require 'pathname'
$LOAD_PATH << File.join(File.dirname(Pathname.new(__FILE__).realpath),'../lib')
require 'easy_mplayer'

#
# a more full-featured script, that gives basic pause/ff/rw support,
# and reports various statistics by the callback mechanism
#

class MyApp
  def show(msg)
    puts 'EXAMPLE<callbacks> ' + msg
  end

  def process_key(key)
    case key
    when 'q', 'Q' then @mplayer.stop
    when " "      then @mplayer.pause_or_unpause
    when "\e[A"   then @mplayer.seek_forward(60)     #    UP arrow
    when "\e[B"   then @mplayer.seek_reverse(60)     #  DOWN arrow
    when "\e[C"   then @mplayer.seek_forward         # RIGHT arrow
    when "\e[D"   then @mplayer.seek_reverse         #  LEFT arrow
    end
  end

  def read_keys
    x = IO.select([$stdin], nil, nil, 0.1)
    return if !x or x.empty?
    @key ||= ''
    @key << $stdin.read(1)
    if @key[0,1] != "\e" or @key.length >= 3
      process_key(@key)
      @key = ''
    end
  end

  def run!
    begin
      @mplayer.play
      
      tty_state = `stty -g`
      system "stty cbreak -echo"  
      read_keys while @mplayer.running?
    ensure
      system "stty #{tty_state}"
    end
  end
  
  def initialize(file)
    @mplayer = MPlayer.new( :path => file )

    @mplayer.callback :audio_stats do
      show "Audio is: "
      show "  ->    sample_rate: #{@mplayer.stats[:audio_sample_rate]} Hz"
      show "  -> audio_channels: #{@mplayer.stats[:audio_channels]}"
      show "  ->   audio_format: #{@mplayer.stats[:audio_format]}"
      show "  ->      data_rate: #{@mplayer.stats[:audio_data_rate]} kb/s"
    end
    
    @mplayer.callback :video_stats do
      show "Video is: "
      show "  -> fourCC: #{@mplayer.stats[:video_fourcc]}"
      show "  -> x_size: #{@mplayer.stats[:video_x_size]}"
      show "  -> y_size: #{@mplayer.stats[:video_y_size]}"
      show "  ->    bpp: #{@mplayer.stats[:video_bpp]}"
      show "  ->    fps: #{@mplayer.stats[:video_fps]}"
    end

    @mplayer.callback :position do |position|
      show "Song position percent: #{position}%"
    end

    @mplayer.callback :played_seconds do |val|
      total  = @mplayer.stats[:total_time]
      show "song position in seconds: #{val} / #{total}"
    end

    @mplayer.callback :pause, :unpause do |pause_state|
      show "song state: " + (pause_state ? "PAUSED!" : "RESUMED!")
    end

    @mplayer.callback :play do
      show "song started!"
    end

    @mplayer.callback :stop do
      show "song ended!"
      puts "final stats were: #{@mplayer.stats.inspect}"
    end
  end
end

# play a file from the command line
raise "usage: #{$0} <file>" if ARGV.length != 1

MyApp.new(ARGV[0]).run!
