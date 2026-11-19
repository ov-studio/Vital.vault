----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/mist.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 18/11/2026
     Desc: Morning mist ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local lerp, clamp, smoothstep = util.math.lerp, util.math.clamp, util.math.smoothstep
local drift, ambient = { 0, 0 }, { 0, 0, 0 }


------------------
--[[ Handlers ]]--
------------------

-- Creates the mist volume shader (a post process screen quad) that fills low ground with mist.
Sky.on("init", function()
    local shader = core.shader.create("files/shaders/mist_volume.gdshader", core.shader.shader_mode.POST_PROCESS)
    shader:set_param("noise_tex", state.noise)
    shader:set_param("density", Config.mist_density)
    shader:set_param("height", Config.mist_height)
    shader:set_param("noise_scale", Config.mist_scale)
    shader:set_param("max_dist", Config.mist_distance)
    shader:set_param("albedo", Config.mist_color)
    state.mist_shader = shader
end)

-- Works out how misty it is and feeds it, the drift and the light into the shader every frame.
-- Mist forms in the night, is thickest at sunrise and burns off with the sun, the evening only brings a part of it back.
-- It is thicker after rain and in fog, and gone in wind, rain, snow and sandstorms. The level eases in and out slowly.
Sky.on("update", function(frame)
    local cur, shader = state.cur, state.mist_shader
    local burn = 1.0 - smoothstep(0.03, 0.40, frame.sun[2])
    local hour = state.time < 12.0 and state.time + 24.0 or state.time
    local evening = lerp(Config.mist_evening, 1.0, smoothstep(18.0, 30.0, hour))
    local calm = 1.0 - clamp((cur.wind - 0.7) / 1.3, 0.0, 1.0)
    local level = clamp(burn * evening * (0.6 + 0.6 * clamp(state.wet, 0.0, 1.0)) * calm + 0.6 * cur.fog, 0.0, 1.0)
    local target = state.mist and Config.mist_strength * level * (1.0 - clamp(cur.rain * 2.0, 0.0, 1.0)) * (1.0 - clamp(cur.snow * 2.0, 0.0, 1.0)) * (1.0 - clamp(cur.sand * 3.0, 0.0, 1.0)) or 0.0
    state.mist_amt = lerp(state.mist_amt, target, clamp(frame.dt * 0.3, 0.0, 1.0))
    state.mist_on = state.mist_amt > 0.003 and frame.camera_pos ~= nil
    if not state.mist_on then return end

    local blow = Config.mist_speed * frame.dt
    drift[1], drift[2] = (drift[1] + frame.wind_x * blow) % 100000.0, (drift[2] + frame.wind_z * blow) % 100000.0
    state.mist_ground = lerp(state.mist_ground or frame.camera_pos[2] - 1.8, frame.camera_pos[2] - 1.8, clamp(frame.dt * 0.5, 0.0, 1.0))
    shader:set_param("strength", state.mist_amt)
    shader:set_param("drift", drift)
    shader:set_param("ground_y", state.mist_ground)
    shader:set_param("light_dir", frame.key_dir)
    shader:set_param("light_color", frame.key_color)

    -- horizon light plus a moonlit floor at night, and lightning flashes
    local sky, glow = frame.cycle.horizon, Config.mist_night
    local night = clamp(frame.cycle.stars, 0.0, 1.0)
    ambient[1], ambient[2], ambient[3] = sky[1] + glow[1] * night + frame.flash * 2.2, sky[2] + glow[2] * night + frame.flash * 2.4, sky[3] + glow[3] * night + frame.flash * 3.2
    shader:set_param("ambient_color", ambient)
end)

-- Draws the mist volume over the finished scene, after the sky, while there is mist.
Sky.on("draw", function()
    if not state.enabled or not state.mist_on then return end

    core.engine.draw_material({ 0, 0 }, core.display.get_resolution(), state.mist_shader, 0, { 0, 0 }, { 1, 1, 1, 1 })
end)


------------------
--[[ Commands ]]--
------------------

-- Toggles the morning mist, no argument flips
-- Usage: /sky_mist [on|off]
util.input.register("sky_mist", function(args)
    state.mist = Sky.switch(args[1], state.mist)
    core.engine.print("info", util.string.format("Mist %s", state.mist and "on" or "off"))
end)
