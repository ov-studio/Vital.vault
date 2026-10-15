----------------------------------------------------------------
--  Resource: shader_outline
--  Script: outline.lua
--  Author: ov-studio
--  Desc: Depth + normal based post-process outline shader
--        (solid "ink" lines, width scales with depth)
----------------------------------------------------------------


--------------------------------------------------
-- Shader source (Godot spatial shader, POST_PROCESS quad)
--
-- Two kinds of lines, both fully solid (no fading):
--
--  1. Silhouettes - DEPTH discontinuities. A second-difference
--     (laplacian) test is used so flat surfaces at grazing angles
--     don't produce false edges. Taps run along 4 axes (2 straight,
--     2 diagonal) so the line keeps the same thickness at any angle.
--     The line is drawn on the NEAR object only, inside its silhouette.
--
--  2. Creases - NORMAL discontinuities (box corners, pillar bases,
--     floor/wall junctions...). These have no depth jump at all, so
--     depth alone can never see them. Taken from the normal buffer.
--
-- Line width is rounded to whole pixels and the depth buffer is read
-- with nearest filtering, so the line can't wobble or break from
-- sub-pixel width changes or interpolated depth values.
--------------------------------------------------

local OUTLINE_SHADER_SRC = [[
    uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
    uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
    uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

    uniform vec2 resolution = vec2(1280.0, 720.0);

    uniform float outline_width     = 2.0;  // width in pixels at depth_reference
    uniform float depth_reference   = 5.0;  // distance (world units) where width == outline_width
    uniform float min_width         = 1.0;  // never thinner than this (pixels)
    uniform float max_width         = 6.0;  // never thicker than this (pixels)
    uniform float depth_scaling     = 1.0;  // 1.0 = scale with depth, 0.0 = constant width
    uniform float edge_threshold    = 0.08; // relative depth jump needed for a silhouette line (lower = more lines)
    uniform float normal_threshold  = 0.35; // 1 - dot(normals) needed for a crease line (lower = more lines, 0 = off)
    uniform vec3  outline_color     = vec3(0.0);

    // Linear view-space distance of the pixel
    float linear_depth(vec2 uv, mat4 inv_proj) {
        float d = texture(depth_tex, uv).r;
        if (d <= 0.00001) return 100000.0; // sky / nothing drawn
        vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
        v.xyz /= v.w;
        return -v.z;
    }

    // Size of the buffers the quad actually reads. With 3D supersampling
    // (gfx.antialiasing.set_scaling_3d_scale > 1) this is larger than the window.
    vec2 buffer_size() {
        return vec2(textureSize(depth_tex, 0));
    }

    float depth_at(vec2 fragCoord, vec2 offset, mat4 inv_proj) {
        return linear_depth((fragCoord + offset) / buffer_size(), inv_proj);
    }

    // View-space surface normal of the pixel
    vec3 normal_at(vec2 fragCoord) {
        vec3 n = texture(normal_tex, fragCoord / buffer_size()).rgb * 2.0 - 1.0;
        float l = length(n);
        return (l > 0.001) ? n / l : vec3(0.0, 0.0, 1.0);
    }

    // 1.0 when the neighbour at 'off' is a differently facing surface at about the same depth.
    // A clearly NEARER neighbour is skipped: that line belongs to the neighbour's own pixel,
    // which keeps silhouette lines on the near object instead of doubling on the far one.
    float crease(vec2 fragCoord, vec2 off, float dc, vec3 nc, mat4 inv_proj) {
        float dn = depth_at(fragCoord, off, inv_proj);
        if (dn < dc * 0.9 || dn > 99999.0) return 0.0;
        vec3 nn = normal_at(fragCoord + off);
        return (1.0 - dot(nc, nn) > normal_threshold) ? 1.0 : 0.0;
    }

    void fragment() {
        vec2 fragCoord = SCREEN_UV * buffer_size();
        vec3 base = texture(screen_tex, SCREEN_UV).rgb;
        mat4 ip = INV_PROJECTION_MATRIX;

        // Buffer pixels per window pixel (1.0 normally, 2.0 with 2x supersampling),
        // so line widths stay the same on screen whatever the render scale is.
        float k = buffer_size().x / max(resolution.x, 1.0);

        float mask = 0.0;
        float dc = depth_at(fragCoord, vec2(0.0), ip);

        if (dc < 99999.0) {           // sky: nothing to outline
            float w = outline_width;
            if (depth_scaling > 0.5) {
                w = clamp(outline_width * depth_reference / max(dc, 0.001), min_width, max_width);
            }
            w = max(floor(w * k + 0.5), 1.0);               // whole buffer pixels only
            float a = max(floor(w * 0.7071 + 0.5), 1.0);    // same reach along the diagonals

            float dl = depth_at(fragCoord, vec2(-w, 0.0), ip);
            float dr = depth_at(fragCoord, vec2( w, 0.0), ip);
            float du = depth_at(fragCoord, vec2(0.0, -w), ip);
            float dd = depth_at(fragCoord, vec2(0.0,  w), ip);
            float d1 = depth_at(fragCoord, vec2(-a, -a), ip);
            float d2 = depth_at(fragCoord, vec2( a,  a), ip);
            float d3 = depth_at(fragCoord, vec2( a, -a), ip);
            float d4 = depth_at(fragCoord, vec2(-a,  a), ip);

            // Positive only when neighbours are FARTHER than this pixel
            // -> line is drawn on the near object, staying inside its silhouette.
            // Planar surfaces (any slope) give ~0.
            float lap_h  = (dl + dr - 2.0 * dc) / dc;
            float lap_v  = (du + dd - 2.0 * dc) / dc;
            float lap_d1 = (d1 + d2 - 2.0 * dc) / dc;
            float lap_d2 = (d3 + d4 - 2.0 * dc) / dc;
            float e = max(max(lap_h, lap_v), max(lap_d1, lap_d2));

            if (e > edge_threshold) mask = 1.0;

            // Creases: half reach on each side of the fold, so the total line is about as wide as a silhouette line
            if (mask < 0.5 && normal_threshold > 0.001) {
                float wn = max(floor(w * 0.5 + 0.5), 1.0);
                vec3 nc = normal_at(fragCoord);
                mask = max(mask, crease(fragCoord, vec2(-wn, 0.0), dc, nc, ip));
                mask = max(mask, crease(fragCoord, vec2( wn, 0.0), dc, nc, ip));
                mask = max(mask, crease(fragCoord, vec2(0.0, -wn), dc, nc, ip));
                mask = max(mask, crease(fragCoord, vec2(0.0,  wn), dc, nc, ip));
            }
        }

        ALBEDO = mix(base, outline_color, mask);
    }
]]


--------------------------------------------------
-- State
--------------------------------------------------

local Outline = {
    enabled          = true,
    shader           = nil,
    width            = 3.0,   -- pixels at depth_reference
    depth_reference  = 5.0,   -- world units
    min_width        = 1.0,
    max_width        = 6.0,
    depth_scaling    = true,
    edge_threshold   = 0.06,  -- silhouettes (depth)
    normal_threshold = 0.35,  -- creases (normals), 0 = off
    color            = {0/255, 0/255, 0/255},
}

--------------------------------------------------
-- Init (with error handling)
--------------------------------------------------

local function init()
    local shader = core.shader.create_from_raw(OUTLINE_SHADER_SRC, core.shader.shader_mode.POST_PROCESS)
    if not shader then
        core.engine.print("info", "[Outline] Shader compilation failed")
        Outline.shader = nil
        Outline.enabled = false
        return
    end
    Outline.shader = shader
    core.engine.print("info", "[Outline] Shader created")
end


--------------------------------------------------
-- Toggle / setter helpers
--------------------------------------------------

function Outline.toggle(state)
    if type(state) ~= "boolean" then
        state = not Outline.enabled
    end
    if state == Outline.enabled then return false end
    Outline.enabled = state
    core.engine.print("info", "[Outline] Toggled to", state)
    return true
end

function Outline.isEnabled()
    return Outline.enabled
end

-- Set outline width (in pixels at depth_reference)
function Outline.setWidth(w)
    w = tonumber(w) or 1.0
    if w < 0.1 then w = 0.1 end
    Outline.width = w
    core.engine.print("info", "[Outline] Width set to", w)
end

-- Set the distance (world units) at which width == Outline.width
function Outline.setDepthReference(d)
    d = tonumber(d) or 5.0
    if d < 0.1 then d = 0.1 end
    Outline.depth_reference = d
    core.engine.print("info", "[Outline] Depth reference set to", d)
end

-- Set min / max width clamp (pixels)
function Outline.setLimits(min_w, max_w)
    min_w = tonumber(min_w) or Outline.min_width
    max_w = tonumber(max_w) or Outline.max_width
    if min_w > max_w then min_w, max_w = max_w, min_w end
    Outline.min_width, Outline.max_width = min_w, max_w
    core.engine.print("info", "[Outline] Limits set to", min_w, max_w)
end

-- Relative depth jump required to draw a silhouette line (0.02 = very sensitive, 0.3 = only big silhouettes)
function Outline.setThreshold(t)
    t = tonumber(t) or 0.08
    if t < 0.005 then t = 0.005 end
    Outline.edge_threshold = t
    core.engine.print("info", "[Outline] Edge threshold set to", t)
end

-- Normal change required to draw a crease line, as 1 - dot(n1, n2)
-- (0.1 = ~25 deg, 0.35 = ~50 deg, 1.0 = 90 deg corners only, 0 = creases off)
function Outline.setNormalThreshold(t)
    t = tonumber(t) or 0.35
    if t < 0.0 then t = 0.0 end
    Outline.normal_threshold = t
    core.engine.print("info", "[Outline] Normal threshold set to", t)
end

function Outline.setColor(r, g, b)
    Outline.color = {tonumber(r) or 0.0, tonumber(g) or 0.0, tonumber(b) or 0.0}
    core.engine.print("info", "[Outline] Color set to", Outline.color[1], Outline.color[2], Outline.color[3])
end

function Outline.toggleDepthScaling(state)
    if type(state) ~= "boolean" then state = not Outline.depth_scaling end
    Outline.depth_scaling = state
    core.engine.print("info", "[Outline] Depth scaling", state)
end

-- usage: outline <width> [depth_reference] [min] [max]
util.input.register("outline", function(args)
    local width = tonumber(args[1])
    if not width then
        return core.engine.print("warn", "Usage: outline <width> [depth_ref] [min] [max]")
    end
    Outline.setWidth(width)
    if args[2] then Outline.setDepthReference(args[2]) end
    if args[3] or args[4] then Outline.setLimits(args[3], args[4]) end
    core.engine.print("info", util.string.format("Outline width successfully set to width %s", width))
end)

-- usage: outline_threshold <value>
util.input.register("outline_threshold", function(args)
    if not tonumber(args[1]) then
        return core.engine.print("warn", "Usage: outline_threshold <value>")
    end
    Outline.setThreshold(args[1])
end)

-- usage: outline_normal <value>   (0 = creases off)
util.input.register("outline_normal", function(args)
    if not tonumber(args[1]) then
        return core.engine.print("warn", "Usage: outline_normal <value>")
    end
    Outline.setNormalThreshold(args[1])
end)


--------------------------------------------------
-- Draw loop
--------------------------------------------------

util.event.on("sandbox:draw", function()
    if not Outline.enabled or not Outline.shader then return end

    local res = core.display.get_resolution()
    local s = Outline.shader
    s:set_param("resolution",       res)
    s:set_param("outline_width",    Outline.width)
    s:set_param("depth_reference",  Outline.depth_reference)
    s:set_param("min_width",        Outline.min_width)
    s:set_param("max_width",        Outline.max_width)
    s:set_param("depth_scaling",    Outline.depth_scaling and 1.0 or 0.0)
    s:set_param("edge_threshold",   Outline.edge_threshold)
    s:set_param("normal_threshold", Outline.normal_threshold)
    s:set_param("outline_color",    Outline.color)
    s:set_param("screen_tex",    core.display.get_texture())

    core.engine.draw_material(
        {0, 0},          -- top-left corner
        res,             -- full viewport size
        s,               -- our POST_PROCESS shader
        0,               -- rotation
        {0, 0},          -- pivot
        {1, 1, 1, 1}     -- tint
    )
end)


util.input.bind(util.input.key.O, "down", function()
    Outline.toggle()
end)

util.input.bind(util.input.key.P, "down", function()
    Outline.toggleDepthScaling()
end)


--------------------------------------------------
-- Bootstrap
--------------------------------------------------

init()

-- Globally exposed functions
_G["outlineToggle"]             = Outline.toggle
_G["outlineIsEnabled"]          = Outline.isEnabled
_G["outlineSetWidth"]           = Outline.setWidth
_G["outlineSetDepthReference"]  = Outline.setDepthReference
_G["outlineSetLimits"]          = Outline.setLimits
_G["outlineSetThreshold"]       = Outline.setThreshold
_G["outlineSetNormalThreshold"] = Outline.setNormalThreshold
_G["outlineSetColor"]           = Outline.setColor
_G["outlineToggleDepthScaling"] = Outline.toggleDepthScaling
