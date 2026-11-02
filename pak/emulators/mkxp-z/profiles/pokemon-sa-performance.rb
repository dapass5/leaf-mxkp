# Optional SA/MakerStudio profile. Install after all game plugins have loaded so
# their alias chains cannot capture these overrides. Never wrap Graphics.update.
module LeafSAPerformance
  class << self
    attr_reader :settings

    def read_settings
      values = { 'enabled' => 'on', 'shadows' => 'off', 'tile_coordinates' => 'on', 'batched_tiles' => 'on', 'hash_lookup' => 'on', 'speedup_render' => 'on' }
      path = File.join(File.dirname(__FILE__), 'pokemon-sa-performance.conf')
      if File.file?(path)
        File.foreach(path) do |line|
          line = line.split('#', 2).first.to_s.strip
          next if line.empty?
          key, value = line.split('=', 2).map(&:strip)
          raise ArgumentError, "invalid performance setting: #{line}" unless
            values.key?(key) && ['on', 'off'].include?(value)
          values[key] = value
        end
      end
      @settings = values
    end

    def install
      return if @installed
      @installed = true
      read_settings
      return if @settings['enabled'] == 'off'
      applied = []
      if @settings['hash_lookup'] == 'on'
        source = Hash.instance_method(:has_key?).source_location
        if source && source[0].include?("Luka's Scripting Utilities") &&
           Hash.instance_method(:key?).source_location.nil?
          Hash.prepend(FastHashMembership)
          applied << 'fast-hash-membership=on'
        end
      end
      if @settings['shadows'] == 'off'
        if defined?(Sprite_OWShadow)
          Sprite_OWShadow.prepend(NoOverworldShadow)
          applied << 'overworld-shadows=off'
        end
        if defined?(Sprite_Shadow)
          Sprite_Shadow.prepend(NoDynamicShadow)
          applied << 'dynamic-shadows=off'
        end
      end
      if @settings['tile_coordinates'] == 'on' && defined?(TilemapRenderer) &&
         defined?(MakerStudio::ENABLED)
        source = TilemapRenderer.instance_method(:refresh_tile_coordinates).source_location
        if source && source[0].include?('002_RendererOverride.rb')
          TileCoordinates.const_set(:TILE_WIDTH, TilemapRenderer::DISPLAY_TILE_WIDTH)
          TileCoordinates.const_set(:TILE_HEIGHT, TilemapRenderer::DISPLAY_TILE_HEIGHT)
          TilemapRenderer.prepend(TileCoordinates)
          applied << 'fused-tile-coordinates=on'
        end
      end
      if @settings['batched_tiles'] == 'on' && defined?(TilemapRenderer) &&
         TilemapRenderer.method_defined?(:__mkst__update)
        source = TilemapRenderer.instance_method(:__mkst__update).source_location
        if source && source[0].include?('TilemapRenderer')
          [:DISPLAY_TILE_WIDTH, :DISPLAY_TILE_HEIGHT, :ZOOM_X, :ZOOM_Y].each do |name|
            BatchedTiles.const_set(name, TilemapRenderer.const_get(name))
          end
          TilemapRenderer.prepend(BatchedTiles)
          applied << 'batched-tile-loop=on'
        end
      end
      if @settings['speedup_render'] == 'on' && defined?(TilemapRenderer) &&
         defined?(SPEEDUP_STAGES) && SPEEDUP_STAGES == [1, 2, 3] &&
         Graphics.respond_to?(:fast_forward_update)
        graphics_source = Graphics.method(:update).source_location
        renderer_source = TilemapRenderer.instance_method(:update).source_location
        if graphics_source && graphics_source[0].include?('[Better Speed Up]') &&
           renderer_source && renderer_source[0].include?('002_RendererOverride.rb')
          TilemapRenderer.prepend(SpeedupRender)
          applied << 'speedup-map-render=on'
        end
      end
      System.puts("Leaf SA performance: #{applied.join(', ')}")
    rescue StandardError => e
      System.puts("Leaf SA performance setup: #{e.class}: #{e.message}")
    end
  end

  # Better Speed Up skips native presentation but still runs the Ruby map
  # renderer on every logical tick. Prepare map sprites on the LAST skipped
  # tick, immediately before the next presentation (Graphics runs before map
  # logic in Scene_Map). Events/player/interpreters keep their existing cadence.
  module SpeedupRender
    def update
      stage = defined?($GameSpeed) && $GameSpeed.is_a?(Integer) ? $GameSpeed : 0
      factor = stage >= 0 && stage < SPEEDUP_STAGES.length ? SPEEDUP_STAGES[stage] : 1
      phase = defined?($frame) ? $frame : nil
      map = defined?($game_map) && $game_map ? $game_map.map_id : nil
      in_map = defined?($scene) && $scene && $scene.class.to_s == 'Scene_Map'
      temp = defined?($game_temp) ? $game_temp : nil
      safe = in_map && temp && !temp.in_battle && !temp.in_menu
      force = !@leaf_speedup_render_ready || @leaf_speedup_stage != stage ||
              @leaf_speedup_map != map || @need_refresh
      if safe && factor > 1 && phase.is_a?(Integer) && phase >= 0 && phase < factor &&
         !force && phase != factor - 1
        return
      end
      result = super
      @leaf_speedup_render_ready = !!safe
      @leaf_speedup_stage, @leaf_speedup_map = stage, map
      result
    end
  end

  # Keep the shadow object's public lifecycle, without allocating a sprite or
  # loading bitmaps. Character/event update methods remain untouched.
  module NoOverworldShadow
    def initialize(sprite, event, viewport = nil)
      @rsprite, @event, @viewport = sprite, event, viewport
      @sprite = nil
      @disposed = false
    end

    def update; end
    def jump_sprite; end
    def set_bitmap(name); end
  end

  module NoDynamicShadow
    def update
      self.visible = false if visible
    end
  end

  # Luka supports multiple arguments, but builds keys.include? for every query.
  # A successful native lookup for a plain Symbol/Integer is also an exact
  # keys.include? match. All misses and other key types retain the old method,
  # including its unusual == (rather than eql?) and identity-hash behaviour.
  module FastHashMembership
    def has_key?(*keys)
      keys.each do |key|
        next if (key.instance_of?(Symbol) || key.instance_of?(Integer)) && key?(key)
        return false unless super(key)
      end
      true
    end
  end

  module TileCoordinates
    def refresh_tile_coordinates(tile, x, y)
      new_x = (x * TILE_WIDTH) - @pixel_offset_x
      new_y = (y * TILE_HEIGHT) - @pixel_offset_y
      if MakerStudio::ENABLED && (tile.ox != 0 || tile.oy != 0)
        new_x += (tile.ox * tile.zoom_x.abs).round
        new_y += (tile.oy * tile.zoom_y.abs).round
      end
      tile.x = new_x
      tile.y = new_y
    end
  end

  # Replace only the Essentials loop captured by MakerStudio. Its outer update
  # still applies lighting, fog, extended layers and map shadows as before.
  module BatchedTiles
    def __mkst__update
      if @old_tone != @tone
        @tiles.each { |col| col.each { |cell| cell.each { |tile| tile.tone = @tone } } }
        @old_tone = @tone.clone
      end
      if @old_color != @color
        # Match the existing engine's assignment; do not change tint semantics.
        @tiles.each { |col| col.each { |cell| cell.each { |tile| tile.color = @tone } } }
        @old_color = @color.clone
      end
      @tilesets.update
      @autotiles.update
      full = @need_refresh
      if @viewport.ox != @old_viewport_ox || @viewport.oy != @old_viewport_oy
        @old_viewport_ox, @old_viewport_oy = @viewport.ox, @viewport.oy
        full = true
      end
      @screen_moved = @screen_moved_vertically = false
      if $PokemonGlobal.bridge != @bridge
        @bridge = $PokemonGlobal.bridge
        @screen_moved_vertically = true
      end
      full = true if check_if_screen_moved
      width, height = @tiles_horizontal_count, @tiles_vertical_count
      size = width * height
      visited = @leaf_visited_cells
      if !visited || visited.length != size
        visited = @leaf_visited_cells = Array.new(size, false)
      else
        visited.fill(false)
      end
      $map_factory.maps.each do |map|
        dx = (map.display_x.to_f / Game_Map::X_SUBPIXELS).round
        dy = (map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
        dx = ((dx + (Graphics.width / 2)) * ZOOM_X) - (Graphics.width / 2) if ZOOM_X != 1
        dy = ((dy + (Graphics.height / 2)) * ZOOM_Y) - (Graphics.height / 2) if ZOOM_Y != 1
        dx /= DISPLAY_TILE_WIDTH
        dy /= DISPLAY_TILE_HEIGHT
        first_x = -dx > 0 ? -dx : 0
        first_y = -dy > 0 ? -dy : 0
        last_x = map.width - dx - 1
        last_y = map.height - dy - 1
        last_x = width - 1 if last_x >= width
        last_y = height - 1 if last_y >= height
        next if first_x > last_x || first_y > last_y || last_x < 0 || last_y < 0
        # Game_Map#data is unchanged throughout this synchronous tile pass.
        # Fetch it once per map, rather than once for every visible tile layer.
        data = map.data
        i = first_x
        while i <= last_x
          column = @tiles[i]
          tile_x = i + dx
          visit_base = i * height
          j = first_y
          while j <= last_y
            cell = column[j]
            tile_y = j + dy
            layer = 0
            while layer < cell.length
              tile = cell[layer]
              tile_id = data[tile_x, tile_y, layer]
              if full || tile.need_refresh || tile.tile_id != tile_id
                refresh_tile(tile, i, j, map, layer, tile_id)
              else
                refresh_tile_frame(tile, tile_id) if tile.animated && @autotiles.changed
                refresh_tile_coordinates(tile, i, j) if @screen_moved
                refresh_tile_z(tile, map, j, layer, tile_id) if @screen_moved_vertically
              end
              layer += 1
            end
            visited[visit_base + j] = true
            j += 1
          end
          i += 1
        end
      end
      i = 0
      while i < width
        column = @tiles[i]
        visit_base = i * height
        j = 0
        while j < height
          unless visited[visit_base + j]
            column[j].each do |tile|
              tile.set_bitmap('', 0, false, false, 0, nil)
              tile.shows_reflection = false
              tile.bridge = false
            end
          end
          j += 1
        end
        i += 1
      end
      @need_refresh = false
      @autotiles.changed = false
    end
  end
end

# A return trace fires once, then disables itself before applying the profile.
# It also works when PluginManager is defined later than this preload.
leaf_sa_plugin_hook = TracePoint.new(:return) do |event|
  next unless event.method_id == :runPlugins && defined?(PluginManager) &&
              event.self.equal?(PluginManager)
  leaf_sa_plugin_hook.disable
  LeafSAPerformance.install
end
leaf_sa_plugin_hook.enable
