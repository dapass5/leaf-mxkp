# Behaviour checks for the optional profile, without loading proprietary game code.
module System
  def self.puts(*); end
end
Tile = Struct.new(:x, :y, :ox, :oy, :zoom_x, :zoom_y)
module MakerStudio
  ENABLED = true
end
class TilemapRenderer
  DISPLAY_TILE_WIDTH = 32
  DISPLAY_TILE_HEIGHT = 32
  def initialize(px, py); @pixel_offset_x, @pixel_offset_y = px, py; end
  def refresh_tile_coordinates(tile, x, y)
    tile.x = (x * DISPLAY_TILE_WIDTH) - @pixel_offset_x
    tile.y = (y * DISPLAY_TILE_HEIGHT) - @pixel_offset_y
  end
  class_eval <<~RUBY, '[MakerStudio] 002_RendererOverride.rb', 1
    alias before_maker_coordinates refresh_tile_coordinates
    def refresh_tile_coordinates(tile, x, y)
      before_maker_coordinates(tile, x, y)
      return unless MakerStudio::ENABLED
      return if tile.ox == 0 && tile.oy == 0
      tile.x += (tile.ox * tile.zoom_x.abs).round
      tile.y += (tile.oy * tile.zoom_y.abs).round
    end
  RUBY
end
class Sprite_OWShadow
  def initialize(*); raise 'original constructor loaded a shadow bitmap'; end
  def update; raise 'original shadow update ran'; end
  def set_bitmap(*); raise 'original bitmap load ran'; end
  def dispose; @sprite.dispose if @sprite; @disposed = true; end
  def disposed?; @disposed; end
end
class Sprite_Shadow
  attr_accessor :visible
  def initialize; @visible = true; update; end
  def update; raise 'original dynamic shadow calculation ran'; end
end

original = TilemapRenderer.instance_method(:refresh_tile_coordinates)
load File.expand_path('../pak/emulators/mkxp-z/profiles/pokemon-sa-performance.rb', __dir__)
raise 'installed before plugins finished' if TilemapRenderer.ancestors.include?(LeafSAPerformance::TileCoordinates)
module PluginManager
  def self.runPlugins
    raise 'installed during plugin loading' if Sprite_OWShadow.ancestors.include?(LeafSAPerformance::NoOverworldShadow)
    :plugins_loaded
  end
end
raise 'plugin return changed' unless PluginManager.runPlugins == :plugins_loaded
raise 'late installation missing' unless TilemapRenderer.ancestors.include?(LeafSAPerformance::TileCoordinates)
ancestor_count = TilemapRenderer.ancestors.size
LeafSAPerformance.install
raise 'installed twice' unless ancestor_count == TilemapRenderer.ancestors.size

comparisons = 0
[0, 1, 15, 31, -1].product([0, 7, 31], [0, 1, 16, -16], [0, 16], [-2.0, -0.5, 0.0, 1.0, 1.5, 2.0]).each do |px, py, ox, oy, zoom|
  renderer = TilemapRenderer.new(px, py)
  a = Tile.new(0, 0, ox, oy, zoom, -zoom)
  b = a.dup
  original.bind(renderer).call(a, -2, 13)
  renderer.refresh_tile_coordinates(b, -2, 13)
  raise "tile mismatch #{[px, py, ox, oy, zoom]}" unless a == b
  comparisons += 1
end
MakerStudio.send(:remove_const, :ENABLED)
MakerStudio.const_set(:ENABLED, false)
renderer = TilemapRenderer.new(3, 7)
a = Tile.new(0, 0, 16, 16, 2.0, 2.0)
b = a.dup
original.bind(renderer).call(a, 2, 4)
renderer.refresh_tile_coordinates(b, 2, 4)
raise 'disabled MakerStudio transform changed' unless a == b

shadow = Sprite_OWShadow.new(Object.new, Object.new)
raise 'fresh shadow disposed' if shadow.disposed?
shadow.update
shadow.set_bitmap('replacement')
shadow.dispose
raise 'dispose lifecycle lost' unless shadow.disposed?
dynamic = Sprite_Shadow.new
raise 'dynamic shadow visible' if dynamic.visible
dynamic.visible = true
dynamic.update
raise 'dynamic shadow reappeared' if dynamic.visible
puts "SA performance: #{comparisons} coordinate/transform cases, late plugin loading, idempotency and shadow lifecycle passed"

# Verify rollback and malformed settings in fresh processes, with configuration
# next to a temporary profile rather than changing the checked-in defaults.
require 'tmpdir'
require 'fileutils'
require 'rbconfig'
Dir.mktmpdir('leaf-sa-profile') do |dir|
  profile = File.join(dir, 'pokemon-sa-performance.rb')
  FileUtils.cp(File.expand_path('../pak/emulators/mkxp-z/profiles/pokemon-sa-performance.rb', __dir__), profile)
  ['enabled=off', 'shadows=invalid'].each do |configuration|
    File.write(File.join(dir, 'pokemon-sa-performance.conf'), configuration)
    check = <<~RUBY
      module System; def self.puts(*); end; end
      class Sprite_OWShadow
        def update; :original; end
      end
      load ARGV[0]
      module PluginManager; def self.runPlugins; :done; end; end
      raise 'plugin return changed' unless PluginManager.runPlugins == :done
      raise 'disabled/invalid configuration applied an override' unless Sprite_OWShadow.new.update == :original
    RUBY
    raise 'configuration rollback failed' unless system(RbConfig.ruby, '-e', check, profile)
  end
end
puts 'SA performance: disabled profile and malformed configuration leave original methods intact'
