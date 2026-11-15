----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/sky.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sky shader: gradient, sun, moon and stars ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local max, PI = util.math.max, util.math.pi
local clamp, rad = Math.clamp, Math.rad


------------------
--[[ Handlers ]]--
------------------

-- Creates the sky shader (a post process screen quad) and loads the moon texture.
Sky.on("init", function()
    local shader = core.shader.create("files/shaders/sky.gdshader", core.shader.shader_mode.POST_PROCESS)
    state.shader = shader
    state.moon = core.image.create("files/textures/moon.png", true)
    shader:set_param("moon_tex", state.moon)
    core.engine.print("info", "[dynamic_sky] sky shader created")
end)

-- Feeds the sun, moon, time of day colours, weather and lightning into the sky shader every frame.
Sky.on("update", function(frame)
    local shader, cycle = state.shader, frame.cycle
    shader:set_param("sun_dir", frame.sun)
    shader:set_param("moon_dir", frame.moon)
    shader:set_param("sun_size", rad(state.sun_deg))
    shader:set_param("moon_size", rad(state.moon_deg))
    shader:set_param("star_axis", frame.axis)
    shader:set_param("star_angle", frame.angle)
    shader:set_param("zenith_color", cycle.zenith)
    shader:set_param("horizon_color", cycle.horizon)
    shader:set_param("ground_color", cycle.ground)
    shader:set_param("glow_color", cycle.glow)
    shader:set_param("glow_strength", cycle.glow_strength * frame.light_left)
    shader:set_param("horizon_falloff", max(3.5 - state.cur.haze * 1.6, 0.8))  -- haze widens the bright horizon band
    shader:set_param("sun_color", cycle.sun_color)

    -- sunlight colour after travelling through the atmosphere (Kasten-Young air mass + Rayleigh-ish
    -- per-channel extinction): warm white high up, yellow, orange, then deep red at the horizon.
    -- haze/dust makes the path "longer", so hazy weather gives redder suns.
    local sun_height = clamp(frame.sun[2], 0.0, 1.0)
    local elevation_rad = sun_height + sun_height * sun_height * sun_height / 6.0 + 0.075 * sun_height ^ 5  -- asin() without needing it
    local elevation_deg = elevation_rad * 180.0 / PI
    local air_mass = 1.0 / (sun_height + 0.50572 * (elevation_deg + 6.07995) ^ -1.6364) * (1.0 + 0.5 * state.cur.haze)
    local red, green, blue = 2.718281828 ^ (-0.055 * air_mass), 2.718281828 ^ (-0.105 * air_mass), 2.718281828 ^ (-0.245 * air_mass)
    local peak = max(red, max(green, blue))
    red, green, blue = red / peak * state.cur.tr, green / peak * state.cur.tg, blue / peak * state.cur.tb
    peak = max(red, max(green, blue))
    state.sun_rgb = { red / peak, green / peak, blue / peak }
    shader:set_param("sun_phys", state.sun_rgb)
    shader:set_param("sun_intensity", 25.0 * frame.light_left)
    shader:set_param("sun_hdr", Config.sun_hdr)
    shader:set_param("moon_color", Config.night_light.color)
    shader:set_param("star_visibility", cycle.stars * (1.0 - state.cur.dark * 0.7))
    shader:set_param("exposure", cycle.exposure * Config.exposure * (1.0 + frame.flash * 1.7))
end)

-- Draws the sky shader as a fullscreen quad every frame while the sky is enabled.
Sky.on("draw", function()
    if not state.enabled then return end
    
    core.engine.draw_material({ 0, 0 }, core.display.get_resolution(), state.shader, 0, { 0, 0 }, { 1, 1, 1, 1 })
end)


-----------------
--[[ Exports ]]--
-----------------

-- Public API surface exposed to other resources: switch the whole sky on or off.
util.export.register("toggle", function() state.enabled = not state.enabled end)


------------------
--[[ Commands ]]--
------------------

-- Switches the whole sky shader on or off
-- Usage: /sky_toggle
util.input.register("sky_toggle", function()
    state.enabled = not state.enabled
    core.engine.print("info", "[dynamic_sky] enabled:", state.enabled)
end)
