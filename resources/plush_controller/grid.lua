----------------------------------------------------------------
--  Resource: shader_grid
--  Script: grid.lua
--  Author: ov-studio
--  Desc: World-space 1x1m grid shader applied to every model
--        (no UVs / textures needed, ideal for blockout levels)
----------------------------------------------------------------


--------------------------------------------------
-- Shader source (Godot spatial shader)
--
-- The grid is projected in WORLD space along the dominant axis of the
-- surface normal (box mapping), so:
--   * every face gets cells of exactly cell_size meters, whatever its scale
--   * no UV unwrap and no texture is needed in Blender
--   * neighbouring faces line up seamlessly
-- Lines are anti-aliased with fwidth() and fade out in the distance
-- to avoid moire. Every `major_every` cells a thicker/darker line is drawn.
--------------------------------------------------

local GRID_SHADER_SRC = [[
    shader_type spatial;
    render_mode cull_disabled; // draw both sides, so single-sided / flipped-normal faces don't disappear
    
    uniform vec3  base_color    : source_color = vec3(0.85, 0.85, 0.85);
    uniform vec3  line_color    : source_color = vec3(0.8, 0.8, 0.8);
    uniform vec3  major_color   : source_color = vec3(0.0, 0.0, 0.0);
    uniform float cell_size     = 0.2;   // meters per cell
    uniform float line_width    = 0.025; // meters (minor lines)
    uniform float major_width   = 0.05;  // meters (major lines)
    uniform float major_every   = 10.0;  // a major line every N cells (<= 1 disables)
    uniform float roughness_val = 0.9;
    uniform float shade_faces   = 0.12;  // 0 = flat, >0 = darken sides/bottom for readability

    varying vec3 w_pos;
    varying vec3 w_nrm;

    void vertex() {
        w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        w_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
    }

    // Anti-aliased line mask for one 2D plane coordinate
    float grid_lines(vec2 p, float period, float width) {
        vec2 q = p / period;
        vec2 w = vec2(width / period);
        vec2 fw = max(fwidth(q), vec2(0.00001));
        vec2 half_w = max(w * 0.5, fw * 0.5);        // never thinner than ~1 pixel
        vec2 d = abs(fract(q + 0.5) - 0.5);          // distance to nearest line (0..0.5)
        vec2 m = 1.0 - smoothstep(half_w, half_w + fw, d);
        // fade out lines that get smaller than a pixel-ish cell (kills moire)
        vec2 fade = 1.0 - smoothstep(vec2(0.25), vec2(0.5), fw);
        return max(m.x * fade.x, m.y * fade.y);
    }

    void fragment() {
        // Flip for back faces so shading is correct when seen from behind
        vec3 n = normalize(w_nrm) * (FRONT_FACING ? 1.0 : -1.0);
        vec3 a = abs(n);

        // Pick the projection plane from the dominant normal axis
        vec2 uv;
        if (a.y >= a.x && a.y >= a.z)      uv = w_pos.xz;   // floors / ceilings
        else if (a.x >= a.z)               uv = w_pos.zy;   // walls facing X
        else                               uv = w_pos.xy;   // walls facing Z

        float minor = grid_lines(uv, cell_size, line_width);
        float major = (major_every > 1.0)
            ? grid_lines(uv, cell_size * major_every, major_width)
            : 0.0;

        // Tops stay bright, sides/undersides get a touch darker
        float up = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
        vec3 base = base_color * (1.0 - shade_faces * (1.0 - up));

        vec3 col = mix(base, line_color, minor);
        col = mix(col, major_color, major);

        ALBEDO = col;
        ROUGHNESS = roughness_val;
        METALLIC = 0.0;
    }
]]


--------------------------------------------------
-- State
--------------------------------------------------

local Grid = {
    enabled     = true,
    shader      = nil,
    cell_size   = 0.2,
    line_width  = 0.025,
    major_every = 10.0,
}

--------------------------------------------------
-- Init (with error handling)
--------------------------------------------------

local function init()
    local shader = core.shader.create_from_raw(GRID_SHADER_SRC, core.shader.shader_mode.SPATIAL)
    if not shader then
        core.engine.print("info", "[Grid] Shader compilation failed")
        Grid.shader = nil
        Grid.enabled = false
        return
    end
    Grid.shader = shader
    -- "*" model, "*" component, "*" material -> every surface of every model, including future spawns
    local count = shader:apply_to_material("*", "*", "*")
    core.engine.print("info", "[Grid] Shader created, applied to", count, "surfaces")
end


--------------------------------------------------
-- Toggle / setter helpers
--------------------------------------------------

function Grid.toggle(state)
    if not Grid.shader then return false end
    if type(state) ~= "boolean" then state = not Grid.enabled end
    if state == Grid.enabled then return false end
    Grid.enabled = state
    if state then
        Grid.shader:apply_to_material("*", "*", "*")
    else
        Grid.shader:remove_from_material("*", "*", "*")
    end
    core.engine.print("info", "[Grid] Toggled to", state)
    return true
end

function Grid.isEnabled()
    return Grid.enabled
end

-- Meters per cell
function Grid.setCellSize(s)
    s = tonumber(s) or 1.0
    if s < 0.05 then s = 0.05 end
    Grid.cell_size = s
    if Grid.shader then Grid.shader:set_param("cell_size", s) end
    core.engine.print("info", "[Grid] Cell size set to", s)
end

-- Minor line thickness in meters
function Grid.setLineWidth(w)
    w = tonumber(w) or 0.025
    if w < 0.001 then w = 0.001 end
    Grid.line_width = w
    if Grid.shader then
        Grid.shader:set_param("line_width", w)
        Grid.shader:set_param("major_width", w * 2.0)
    end
    core.engine.print("info", "[Grid] Line width set to", w)
end

-- Draw a thicker line every N cells (<= 1 disables)
function Grid.setMajorEvery(n)
    n = tonumber(n) or 10.0
    Grid.major_every = n
    if Grid.shader then Grid.shader:set_param("major_every", n) end
    core.engine.print("info", "[Grid] Major line every", n)
end

function Grid.setColors(base, line, major)
    if not Grid.shader then return end
    if base  then Grid.shader:set_param("base_color",  base)  end
    if line  then Grid.shader:set_param("line_color",  line)  end
    if major then Grid.shader:set_param("major_color", major) end
end

-- usage: grid [cell_size] [line_width] [major_every]
util.input.register("grid", function(args)
    if args[1] then Grid.setCellSize(args[1]) end
    if args[2] then Grid.setLineWidth(args[2]) end
    if args[3] then Grid.setMajorEvery(args[3]) end
    if not (args[1] or args[2] or args[3]) then
        core.engine.print("warn", "Usage: grid [cell_size] [line_width] [major_every]")
    end
end)

util.input.bind(util.input.key.G, "down", function()
    Grid.toggle()
end)


--------------------------------------------------
-- Bootstrap
--------------------------------------------------

init()

-- Globally exposed functions
_G["gridToggle"]       = Grid.toggle
_G["gridIsEnabled"]    = Grid.isEnabled
_G["gridSetCellSize"]  = Grid.setCellSize
_G["gridSetLineWidth"] = Grid.setLineWidth
_G["gridSetMajorEvery"]= Grid.setMajorEvery
_G["gridSetColors"]    = Grid.setColors