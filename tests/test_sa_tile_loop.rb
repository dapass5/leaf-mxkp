require 'ostruct'
module System
  def self.puts(*); end
end
module Graphics
  def self.width; 512; end
  def self.height; 384; end
end
class Game_Map
  X_SUBPIXELS = Y_SUBPIXELS = 4
end
class TestTile
  attr_accessor :tile_id, :need_refresh, :animated, :frame, :x, :y, :z,
                :shows_reflection, :bridge, :tone, :color, :bitmap
  def initialize
    @tile_id = -1
    @need_refresh = true
    @animated = true
    @frame = 0
  end
  def set_bitmap(_, id, _, _, _, bitmap)
    @tile_id, @bitmap, @need_refresh = id, bitmap, true
  end
end
class TestTable
  def initialize(salt); @salt = salt; end
  def [](x, y, layer); @salt + 100 * x + 10 * y + layer; end
end
class TestMap
  attr_accessor :display_x, :display_y, :width, :height, :reads
  def initialize(x, y, width, height, salt)
    @display_x, @display_y, @width, @height = x, y, width, height
    @table, @reads = TestTable.new(salt), 0
  end
  def data; @reads += 1; @table; end
end
class TestAtlas
  attr_accessor :changed
  def update; end
end
class TilemapRenderer
  DISPLAY_TILE_WIDTH = DISPLAY_TILE_HEIGHT = 32
  ZOOM_X = ZOOM_Y = 1
  attr_accessor :motion, :full
  def initialize
    @tiles_horizontal_count, @tiles_vertical_count = 5, 4
    @tiles = Array.new(5) { Array.new(4) { Array.new(3) { TestTile.new } } }
    @tone = @old_tone = [0, 0, 0, 0]
    @color = @old_color = [0, 0, 0, 0]
    @viewport = OpenStruct.new(ox: 0, oy: 0)
    @old_viewport_ox = @old_viewport_oy = 0
    @tilesets, @autotiles = TestAtlas.new, TestAtlas.new
    @pixel_offset_x = @pixel_offset_y = 0
    @bridge = 0
    @need_refresh, @motion, @full = true, :still, false
  end
  def check_if_screen_moved
    @screen_moved = @motion != :still
    @screen_moved_vertically ||= @motion == :vertical
    @full
  end
  def refresh_tile(tile, x, y, map, layer, id)
    tile.tile_id, tile.need_refresh = id, false
    refresh_tile_coordinates(tile, x, y)
    refresh_tile_z(tile, map, y, layer, id)
    tile.bitmap = :loaded
  end
  def refresh_tile_coordinates(tile, x, y)
    tile.x, tile.y = x * 32 - @pixel_offset_x, y * 32 - @pixel_offset_y
  end
  def refresh_tile_z(tile, map, y, layer, id); tile.z = y * 32 + layer + $PokemonGlobal.bridge; end
  def refresh_tile_frame(tile, id); tile.frame += 1; end
  def snapshot
    [@tiles.map { |col| col.map { |cell| cell.map { |t| t.instance_variables.sort.map { |k| [k, t.instance_variable_get(k)] } } } },
     @need_refresh, @autotiles.changed, @old_tone, @old_color, @bridge]
  end
end
load File.expand_path('../pak/emulators/mkxp-z/profiles/pokemon-sa-performance.rb', __dir__)
[:DISPLAY_TILE_WIDTH, :DISPLAY_TILE_HEIGHT, :ZOOM_X, :ZOOM_Y].each do |name|
  LeafSAPerformance::BatchedTiles.const_set(name, TilemapRenderer.const_get(name))
end
class FastRenderer < TilemapRenderer
  prepend LeafSAPerformance::BatchedTiles
end
$PokemonGlobal = OpenStruct.new(bridge: 0)
$map_factory = OpenStruct.new(maps: [TestMap.new(0, 0, 5, 4, 1)])
renderer = FastRenderer.new
renderer.__mkst__update
raise 'map data not batched' unless $map_factory.maps[0].reads == 1
raise 'refresh flag retained' if renderer.instance_variable_get(:@need_refresh)
raise 'visible tile mismatch' unless renderer.instance_variable_get(:@tiles)[2][1][1].tile_id == 212
visited = renderer.instance_variable_get(:@leaf_visited_cells)
renderer.__mkst__update
raise 'visited buffer not reused' unless visited.equal?(renderer.instance_variable_get(:@leaf_visited_cells))
renderer.instance_variable_get(:@autotiles).changed = true
renderer.motion = :vertical
$PokemonGlobal.bridge = 1
renderer.__mkst__update
tile = renderer.instance_variable_get(:@tiles)[2][1][1]
raise 'animated frame or bridge z lost' unless tile.frame == 1 && tile.z == 34
$map_factory.maps = []
renderer.__mkst__update
raise 'uncovered cell not cleared' unless renderer.instance_variable_get(:@tiles).flatten.all? { |t| t.tile_id == 0 && t.bitmap.nil? && !t.bridge && !t.shows_reflection }
puts 'SA tile loop: map batching, buffer reuse, animated tiles, bridge z and uncovered cells passed'

# Optional local oracle: evaluate the user's existing engine method verbatim
# without distributing game source. Exercise identical scene sequences against it.
if ENV['SA_TILEMAP_SOURCE']
  text = File.read(ENV.fetch('SA_TILEMAP_SOURCE'))
  method_source = text[text.index("  def update\n", text.index('def check_if_screen_moved'))...text.rindex("\nend")]
  raise 'reference method not found' unless method_source
  TilemapRenderer.class_eval(method_source, 'original TilemapRenderer', 1)
  original, fast = TilemapRenderer.new, FastRenderer.new
  checks = 0
  scenarios = [
    [0, 0, 5, 4], [128, 0, 5, 4], [-128, 0, 5, 4], [0, 128, 5, 4],
    [0, -128, 5, 4], [0, 0, 2, 2], [640, 640, 2, 2], [-640, -640, 2, 2]
  ]
  scenarios.each_with_index do |(x, y, w, h), index|
    [:still, :horizontal, :vertical].each do |motion|
      [false, true].each do |full|
        maps = [TestMap.new(x, y, w, h, index), TestMap.new(x + 256, y, 3, 4, 1000)]
        original.motion = fast.motion = motion
        original.full = fast.full = full
        [original, fast].each do |r|
          r.instance_variable_get(:@autotiles).changed = index.even?
          r.instance_variable_set(:@tone, [index, 0, 0, 0])
          r.instance_variable_set(:@color, [0, index, 0, 0])
          r.instance_variable_get(:@viewport).ox = index
        end
        $PokemonGlobal.bridge = index % 2
        $map_factory.maps = Marshal.load(Marshal.dump(maps))
        original.update
        $map_factory.maps = Marshal.load(Marshal.dump(maps))
        fast.__mkst__update
        raise "reference mismatch #{[index, motion, full]}" unless original.snapshot == fast.snapshot
        checks += 1
      end
    end
  end
  puts "SA tile loop: #{checks} scene transitions match the original engine method"
end
