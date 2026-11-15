----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/precipitation.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: What rain and snow share: camera, wind, light colour and particle level ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local sin, floor, min, max = util.math.sin, util.math.floor, util.math.min, util.math.max
local lerp, clamp = Math.lerp, Math.clamp


---------------
--[[ Utils ]]--
---------------

-- Shared by rain and snow: the emitter shows more or fewer particles in 8 steps (changing the amount restarts
-- the pool, so only step changes do it) and the shader's density smooths between the steps. Returns the density for
-- the shader, or nil (emitter hidden) when there is none. state[key] remembers the current step.
function Sky.level(emitter, key, full, intensity, active)
    local steps = 8.0
    local level = active and min(steps, floor(intensity * steps) + 1) or 0
    if level <= 0 then
        if state[key] ~= 0 then state[key] = 0; emitter:set_visible(false); emitter:stop() end   -- a hidden emitter must not keep simulating
        return nil
    end
    
    if state[key] ~= level then
        state[key] = level
        emitter:set_amount(max(40, floor(full * level / steps)))
        emitter:set_visible(true)
        emitter:emit()
    end
    return clamp(intensity * steps / level, 0.0, 1.0) ^ 0.8
end


------------------
--[[ Handlers ]]--
------------------

-- Publishes what rain and snow share every frame: the camera position, the daylight that tints them, the near white
-- drop colour and the horizontal wind speed.
Sky.on("update", function(frame)
    local camera = core.camera.get_active()
    if camera then frame.camera_pos = camera:get_global_position() end
    frame.daylight = clamp(0.10 + 0.80 * clamp(frame.cycle.light_energy, 0.0, 1.0) ^ 0.7, 0.08, 1.0) * (1.0 + frame.flash * 3.0)

    -- horizon colour, kept close to white: the tint of the drops / flakes against the sky
    local horizon = frame.cycle.horizon
    local peak = max(horizon[1], max(horizon[2], max(horizon[3], 1e-3)))
    frame.precip_r, frame.precip_g, frame.precip_b = lerp(horizon[1] / peak, 1.0, 0.45), lerp(horizon[2] / peak, 1.0, 0.45), lerp(horizon[3] / peak, 1.0, 0.45)

    -- horizontal speed of the falling precipitation
    local gust = 1.0 + 0.25 * sin(state.cloud_t * 0.35) * sin(state.cloud_t * 0.113 + 1.7)
    local wind_speed = state.cur.wind * Config.rain_wind_mps * gust
    frame.wind_x, frame.wind_z = frame.wind_dir[1] * wind_speed, frame.wind_dir[3] * wind_speed
end)


------------------
--[[ Commands ]]--
------------------

-- Toggles the rain and snow particles, no argument flips
-- Usage: /sky_precip [on|off]
util.input.register("sky_precip", function(args)
    state.precip = Sky.switch(args[1], state.precip)
    core.engine.print("info", "[dynamic_sky] precipitation particles:", state.precip and "on" or "off")
end)
