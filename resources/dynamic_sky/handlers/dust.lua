----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/dust.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 16/11/2026
     Desc: Sandstorm dust volume ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local sin, sqrt, pi = util.math.sin, util.math.sqrt, util.math.pi
local lerp, clamp = util.math.lerp, util.math.clamp
local drift_a, drift_b, ambient = { 0, 0 }, { 0, 0 }, { 0, 0, 0 }


------------------
--[[ Handlers ]]--
------------------

-- Creates the dust volume shader (a post process screen quad) that fogs the scene with blowing dust.
Sky.on("init", function()
    local shader = core.shader.create("files/shaders/dust_volume.gdshader", core.shader.shader_mode.POST_PROCESS)
    shader:set_param("noise_tex", state.noise)
    shader:set_param("density", Config.dust_density)
    shader:set_param("height", Config.dust_height)
    shader:set_param("noise_scale", Config.dust_scale)
    shader:set_param("stretch", Config.dust_stretch)
    shader:set_param("max_dist", Config.dust_distance)
    shader:set_param("sky_veil", Config.dust_sky)
    shader:set_param("albedo", Config.dust_color)
    state.dust_shader = shader
end)

-- Blows the dust along the wind and feeds the storm level and the time of day light into the shader every frame.
-- The dust is carried along the wind in the world (the small billows blow faster than the big ones), so when the wind
-- turns the dust bends with it. The offsets wrap after 100 km to keep the shader precise.
Sky.on("update", function(frame)
    local shader = state.dust_shader
    state.dust_on = state.precip and frame.camera_pos ~= nil and state.cur.sand > 0.01
    if not state.dust_on then return end

    local speed = sqrt(frame.wind_x * frame.wind_x + frame.wind_z * frame.wind_z) * Config.dust_speed
    local blow_x, blow_z = frame.wind_dir[1] * speed * frame.dt, frame.wind_dir[3] * speed * frame.dt
    drift_a[1], drift_a[2] = (drift_a[1] + blow_x) % 100000.0, (drift_a[2] + blow_z) % 100000.0
    drift_b[1], drift_b[2] = (drift_b[1] + blow_x * 1.35) % 100000.0, (drift_b[2] + blow_z * 1.35) % 100000.0
    state.dust_ground = lerp(state.dust_ground or frame.camera_pos[2] - 1.8, frame.camera_pos[2] - 1.8, clamp(frame.dt * 0.5, 0.0, 1.0))

    local gust = 1.0 - Config.dust_gust + Config.dust_gust * (0.5 + 0.5 * sin(state.cloud_t * 0.4 * pi))
    shader:set_param("strength", clamp(state.cur.sand, 0.0, 1.0) * gust)
    shader:set_param("wind_dir", frame.wind_dir)
    shader:set_param("drift_a", drift_a)
    shader:set_param("drift_b", drift_b)
    shader:set_param("ground_y", state.dust_ground)
    shader:set_param("light_dir", frame.key_dir)
    shader:set_param("light_color", frame.key_color)

    -- ambient sky light plus a moonlit floor at night, so the dust stays visible after dark, and lightning flashes
    local sky, glow = frame.cycle.ambient_top, Config.dust_night
    local night = clamp(frame.cycle.stars, 0.0, 1.0)
    ambient[1], ambient[2], ambient[3] = sky[1] + glow[1] * night + frame.flash * 2.2, sky[2] + glow[2] * night + frame.flash * 2.4, sky[3] + glow[3] * night + frame.flash * 3.2
    frame.dust_ambient = ambient
    shader:set_param("ambient_color", ambient)
end)

-- Draws the dust volume over the finished scene, after the sky, while the storm blows.
Sky.on("draw", function()
    if not state.enabled or not state.dust_on then return end

    core.engine.draw_material({ 0, 0 }, core.display.get_resolution(), state.dust_shader, 0, { 0, 0 }, { 1, 1, 1, 1 })
end)
