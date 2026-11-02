# Test the optional compatibility preload against the game's later redefinition.
module System
  def self.data_directory; '/tmp'; end
  def self.puts(*); end
end
module Graphics
  class << self
    attr_accessor :frame_rate, :delta
    def frame_count; 0; end
    def update; :updated; end
  end
  self.frame_rate = 40
  self.delta = 0
end
load File.expand_path('../pak/emulators/mkxp-z/profiles/pokemon-sa-timing.rb', __dir__)
# The game defines this AFTER preloads. The compatibility method must win.
module Graphics
  def self.delta_s; 0.025 / 1_000_000; end
  class << self
    alias before_speed_update update
    def update; before_speed_update; end
  end
end
assert = ->(condition, message) { raise message unless condition }
assert.call((Graphics.delta_s-0.025).abs < 0.000001, 'fallback uses seconds')
assert.call(Graphics.update == :updated, 'update return value changed')
Graphics.delta = 0.025
assert.call(Graphics.delta_s > 0.02 && Graphics.delta_s < 0.05, 'normal frame delta')
Graphics.delta = 3
assert.call(Graphics.delta_s == 0.1, 'loading pause clamp')
Graphics.delta = Float::NAN
assert.call((Graphics.delta_s-0.025).abs < 0.000001, 'invalid delta fallback')
puts 'SA timing: seconds, preload order, game alias compatibility, invalid delta and pause clamp passed'
