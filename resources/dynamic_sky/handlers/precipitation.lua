----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/precipitation.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: What rain and snow share: camera, wind, light colour and particle level ]]--
----------------------------------------------------------------

local state = Sky.state
local sin, floor, min, max = util.math.sin, util.math.floor, util.math.min, util.math.max
local lerp, clamp = Math.lerp, Math.clamp


-- rain and snow share this: the carrier emitter shows more or fewer particles in 8 steps (changing the amount restarts
-- the pool, so only step changes do it) and the shader's density smooths between the steps. Returns the density for
-- the shader, or nil (carrier hidden) when there is none.
function Sky.level(car, key, full, inten, on)
    local steps = 8.0
    local lvl = on and min(steps, floor(inten * steps) + 1) or 0
    if lvl <= 0 then
        if state[key] ~= 0 then state[key] = 0; pcall(function() car:set_visible(false); car:stop() end) end   -- a hidden emitter must not keep simulating
        return nil
    end
    if state[key] ~= lvl then
        state[key] = lvl
        pcall(function()
            car:set_amount(max(40, floor(full * lvl / steps)))
            car:set_visible(true)
            car:emit()
        end)
    end
    return clamp(inten * steps / lvl, 0.0, 1.0) ^ 0.8
end

Sky.on("update", function(F)
    local cam = core.camera.get_active()
    if cam then
        local ok, p = pcall(cam.get_global_position, cam)
        if ok and type(p) == "table" then F.cpos = p end
    end
    local tc = F.tc
    F.daylight = clamp(0.10 + 0.80 * clamp(tc.light_energy, 0.0, 1.0) ^ 0.7, 0.08, 1.0) * (1.0 + F.FL * 3.0)

    -- horizon colour, kept close to white: the tint of the drops / flakes against the sky
    local ph = tc.horizon
    local pmx = max(ph[1], max(ph[2], max(ph[3], 1e-3)))
    F.pr, F.pg, F.pb = lerp(ph[1] / pmx, 1.0, 0.45), lerp(ph[2] / pmx, 1.0, 0.45), lerp(ph[3] / pmx, 1.0, 0.45)

    -- horizontal speed of the falling precipitation
    local gust = 1.0 + 0.25 * sin(state.cloud_t * 0.35) * sin(state.cloud_t * 0.113 + 1.7)
    local wmps = state.cur.wind * Config.rain_wind_mps * gust
    F.wx, F.wz = F.wd[1] * wmps, F.wd[3] * wmps
    F.R, F.SN = state.cur.rain, state.cur.snow
end)


-----------------
--[[ Input ]]--
-----------------

-- sky_precip on|off : toggle the rain / snow particles (no argument = flip)
util.input.register("sky_precip", function(args)
    state.precip = Sky.switch(args[1], state.precip)
    core.engine.print("info", "[dynamic_sky] precipitation particles:", state.precip and "on" or "off")
end)
