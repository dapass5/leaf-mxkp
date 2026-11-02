# Optional Pokemon SA compatibility profile for upstream mkxp-z 2.4.x.
# SA's Graphics.delta_s divides seconds by 1,000,000. Upstream already
# returns seconds; only override delta_s, never wrap the aliased update chain.
module LeafSATiming
  class << self
    attr_accessor :log_path

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def fallback_delta
      rate = Graphics.frame_rate.to_f
      rate = 40.0 unless rate.finite? && rate > 0
      1.0 / rate
    end
  end

  module GraphicsMethods
    def delta_s
      elapsed = delta.to_f
      # Loading pauses must not skip a whole animation or move actors too far.
      elapsed.finite? && elapsed > 0.00001 ? [elapsed, 0.1].min : LeafSATiming.fallback_delta
    end
  end
end

LeafSATiming.log_path = File.join(System.data_directory, 'leaf-performance.log')
Graphics.singleton_class.prepend(LeafSATiming::GraphicsMethods)
System.puts('Leaf SA: frame timing compatibility enabled (seconds)')

# Bounded, low-frequency samples for device testing. No forced GC or per-frame I/O.
game_thread = Thread.current
Thread.new do
  begin
    before_time = LeafSATiming.clock
    before_frames = Graphics.frame_count
    File.open(LeafSATiming.log_path, 'a') { |f| f.puts("\nSTART #{Time.now} timing-profile=1") }
    36.times do
      sleep(5)
      now = LeafSATiming.clock
      frames = Graphics.frame_count
      fps = (frames - before_frames) / (now - before_time)
      stat = GC.stat
      trace = game_thread.backtrace || []
      File.open(LeafSATiming.log_path, 'a') do |f|
        f.puts("#{Time.now} fps=#{fps.round(2)} target=#{Graphics.frame_rate} frames=#{frames} heap_live=#{stat[:heap_live_slots]} gc=#{stat[:count]}")
        f.puts(trace.first(10))
      end
      before_time, before_frames = now, frames
    end
  rescue StandardError => e
    System.puts("Leaf performance sampler: #{e.class}: #{e.message}")
  end
end
