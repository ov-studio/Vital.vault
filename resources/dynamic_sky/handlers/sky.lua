----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/sky.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Sky shader: gradient, sun, moon and stars ]]--
----------------------------------------------------------------

local state = Sky.state
local max, PI = util.math.max, util.math.pi
local clamp, rad = Math.clamp, Math.rad


--------------
--[[ Init ]]--
--------------

Sky.on("init", function()
    local shader = core.shader.create("files/shaders/sky.gdshader", core.shader.shader_mode.POST_PROCESS)
    if not shader then
        core.engine.print("error", "[dynamic_sky] sky shader failed to compile")
        state.enabled = false
        return false
    end
    state.shader = shader

    -- NASA LROC moon colour map
    state.moon = core.image.create("files/textures/moon.png", true)    -- keep a reference so the texture is not freed while the shader uses it
    shader:set_param("moon_tex", state.moon)
    core.engine.print("info", "[dynamic_sky] sky shader created")
end)


----------------
--[[ Update ]]--
----------------

Sky.on("update", function(F)
    local sh, tc, sun, FL = state.shader, F.tc, F.sun, F.FL

    sh:set_param("sun_dir", sun)
    sh:set_param("moon_dir", F.moon)
    sh:set_param("sun_size", rad(state.sun_deg))
    sh:set_param("moon_size", rad(state.moon_deg))
    sh:set_param("star_axis", F.axis)
    sh:set_param("star_angle", F.ang)
    sh:set_param("zenith_color", tc.zenith)
    sh:set_param("horizon_color", tc.horizon)
    sh:set_param("ground_color", tc.ground)
    sh:set_param("glow_color", tc.glow)
    sh:set_param("glow_strength", tc.glow_strength * F.dark)
    sh:set_param("horizon_falloff", max(3.5 - state.cur.haze * 1.6, 0.8))       -- haze widens the bright horizon band
    sh:set_param("sun_color", tc.sun_color)

    -- sunlight colour after travelling through the atmosphere (Kasten-Young air mass + Rayleigh-ish
    -- per-channel extinction): warm white high up, yellow, orange, then deep red at the horizon.
    -- haze/dust makes the path "longer", so hazy weather gives redder suns.
    local sy = clamp(sun[2], 0.0, 1.0)
    local hrad = sy + sy * sy * sy / 6.0 + 0.075 * sy ^ 5          -- asin() without needing it
    local hdeg = hrad * 180.0 / PI
    local am = 1.0 / (sy + 0.50572 * (hdeg + 6.07995) ^ -1.6364) * (1.0 + 0.5 * state.cur.haze)
    local r, g, b = 2.718281828 ^ (-0.055 * am), 2.718281828 ^ (-0.105 * am), 2.718281828 ^ (-0.245 * am)
    local m = max(r, max(g, b))
    r, g, b = r / m * state.cur.tr, g / m * state.cur.tg, b / m * state.cur.tb
    m = max(r, max(g, b))
    state.sun_rgb = { r / m, g / m, b / m }
    sh:set_param("sun_phys", state.sun_rgb)
    sh:set_param("sun_intensity", 25.0 * F.dark)
    sh:set_param("sun_hdr", Config.sun_hdr)

    sh:set_param("moon_color", Config.night_light.color)
    sh:set_param("star_visibility", tc.stars * (1.0 - state.cur.dark * 0.7))
    sh:set_param("exposure", tc.exposure * Config.exposure * (1.0 + FL * 1.7))
end)


---------------
--[[ Draw ]]--
---------------

-- the sky is a screen quad (same mechanism as a post process effect)
Sky.on("draw", function()
    if not state.enabled or not state.shader then return end
    core.engine.draw_material({ 0, 0 }, core.display.get_resolution(), state.shader, 0, { 0, 0 }, { 1, 1, 1, 1 })
end)


-----------------
--[[ Input ]]--
-----------------

-- sky_toggle: switch the whole sky shader on/off
util.input.register("sky_toggle", function()
    state.enabled = not state.enabled
    core.engine.print("info", "[dynamic_sky] enabled:", state.enabled)
end)


-----------------
--[[ Exports ]]--
-----------------

util.export.register("toggle", function() state.enabled = not state.enabled end)
