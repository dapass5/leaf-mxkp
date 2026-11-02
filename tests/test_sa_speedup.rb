# Displayed map state must match the unmodified renderer at every presentation,
# even though intermediate logical ticks do not need to prepare map sprites.
module System
  def self.puts(*); end
end
SPEEDUP_STAGES = [1, 2, 3]
class Scene_Map; end
class Scene_Menu; end
MapState = Struct.new(:map_id, :position)
TempState = Struct.new(:in_battle, :in_menu)
$scene = Scene_Map.new
$game_map = MapState.new(33, 0)
$game_temp = TempState.new(false, false)
$GameSpeed = 0
$frame = 0
module Graphics
  def self.update; :present; end
  class << self
    alias fast_forward_update update
  end
  singleton_class.class_eval <<~RUBY, '[Better Speed Up] 01_Speed_Up.rb', 1
    def update
      $frame += 1
      return unless $frame % SPEEDUP_STAGES[$GameSpeed] == 0
      fast_forward_update
      $frame = 0
      :present
    end
  RUBY
end
class ReferenceRenderer
  attr_reader :calls, :state
  def initialize; @calls = 0; @need_refresh = true; end
  def update
    @calls += 1
    @state = [$game_map.map_id, $game_map.position]
    @need_refresh = false
    :updated
  end
  def refresh; @need_refresh = true; end
end
class TilemapRenderer < ReferenceRenderer
  class_eval <<~RUBY, '[MakerStudio] 002_RendererOverride.rb', 1
    def update; super; end
  RUBY
end
graphics_update = Graphics.method(:update)
load File.expand_path('../pak/emulators/mkxp-z/profiles/pokemon-sa-performance.rb', __dir__)
module PluginManager
  def self.runPlugins; end
end
PluginManager.runPlugins
raise 'speedup guard failed to install' unless TilemapRenderer.ancestors.include?(LeafSAPerformance::SpeedupRender)
raise 'Graphics alias chain changed' unless Graphics.method(:update) == graphics_update

presentations = 0
[0, 1, 2, 1, 0].each do |stage|
  $GameSpeed, $frame = stage, 0
  reference, optimized = ReferenceRenderer.new, TilemapRenderer.new
  reference.update
  optimized.update
  120.times do |tick|
    if Graphics.update == :present
      raise "displayed map lagged at stage #{stage}, tick #{tick}" unless optimized.state == reference.state
      presentations += 1
    end
    # These stand in for gameplay updates, which must still run EVERY tick.
    $game_map.position += 1
    reference.update
    optimized.update
  end
  expected = stage == 0 ? reference.calls : (reference.calls.to_f / SPEEDUP_STAGES[stage]).ceil + 1
  raise "redundant renderer updates at stage #{stage}" unless optimized.calls <= expected
  if stage == 0
    raise 'normal speed changed' unless optimized.calls == reference.calls
  end
end

$GameSpeed, $frame = 2, 0
renderer = TilemapRenderer.new
raise 'initial renderer skipped' unless renderer.update == :updated
calls = renderer.calls
renderer.update
raise 'intermediate accelerated render not skipped' unless renderer.calls == calls
renderer.refresh
raise 'explicit refresh skipped' unless renderer.update == :updated
$game_map.map_id = 78
raise 'map transfer skipped' unless renderer.update == :updated
$GameSpeed = 1
raise 'speed switch skipped' unless renderer.update == :updated
[:in_menu, :in_battle].each do |flag|
  $game_temp.public_send("#{flag}=", true)
  3.times { raise "#{flag} render skipped" unless renderer.update == :updated }
  $game_temp.public_send("#{flag}=", false)
  raise 'return to overworld skipped' unless renderer.update == :updated
end
$scene = Scene_Menu.new
3.times { raise 'non-map scene skipped' unless renderer.update == :updated }
$scene = Scene_Map.new
$frame = nil
raise 'unknown phase skipped' unless renderer.update == :updated
puts "SA speedup: #{presentations} displayed states match; 1x/2x/3x, refresh, transfers, speed switches, menus and battle boundaries passed"
