----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/weather.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Weather blending, wind and the manual intensity overrides ]]--
----------------------------------------------------------------

local S = Sky.state
local sin, cos = util.math.sin, util.math.cos
local lerp, clamp, norm, rad = Math.lerp, Math.clamp, Math.norm, Math.rad


-------------------
--[[ Weather ]]--
-------------------

Sky.on("update", function(F)
    local dt = F.dt
    local target = Config.weather[S.weather] or Config.weather.partly
    local k = clamp(dt * Config.weather_blend_per_sec, 0, 1)
    local tint = target.tint or { 1.0, 1.0, 1.0 }
    local want = { rain = 0.0, snow = 0.0, fog = 0.0, wind = 1.0, lightning = 0.0, haze = 0.0,
                   tr = tint[1], tg = tint[2], tb = tint[3] }
    for key, v in pairs(target) do if key ~= "tint" then want[key] = v end end
    -- every key blends, so a key a preset does not mention returns to its neutral value
    for key, v in pairs(want) do S.base[key] = lerp(S.base[key], v, k) end
    -- effective values = blended preset + manual intensity (sky_rain / sky_snow / sky_fog / sky_lightning set the level
    -- reached WHILE the weather has that phenomenon, so clear weather still stops it; sky_wind is a multiplier)
    for key, v in pairs(S.base) do S.cur[key] = v end
    for key, v in pairs(S.over) do
        if key == "wind" then S.cur.wind = S.base.wind * v
        else S.cur[key] = v * clamp(S.base[key] / 0.3, 0.0, 1.0) end
    end

    -- wind / cloud evolution accumulate (changing the speed never makes clouds jump)
    local kd = clamp(dt * 0.6, 0, 1)
    S.wdir[1] = lerp(S.wdir[1], S.wdir_t[1], kd)
    S.wdir[2] = lerp(S.wdir[2], S.wdir_t[2], kd)
    local wd = norm({ S.wdir[1], 0, S.wdir[2] })
    for i = 1, 3 do S.wind[i] = (S.wind[i] + wd[i] * Config.wind_speed * S.cur.wind * dt) % Sky.wrap end
    S.cloud_t = (S.cloud_t + dt) % Sky.wrap
    F.wd = wd
end)


-----------------
--[[ Input ]]--
-----------------

-- sky_rain / sky_snow / sky_fog / sky_wind / sky_lightning <value | auto>
-- rain, snow, fog, lightning: 0..1 level reached WHILE the weather has it (clear weather still has none); wind: multiplier, 1 = preset
local overrides = {}
local function make_override(cmd, key, lo, hi)
    util.input.register(cmd, function(args)
        local a = args[1]
        if not a then return core.engine.print("info", util.string.format("[dynamic_sky] %s = %.2f%s", key, S.cur[key], S.over[key] and " (manual)" or " (auto)")) end
        if a == "auto" then S.over[key] = nil
        else
            local v = tonumber(a)
            if not v then return core.engine.print("warn", "Usage: " .. cmd .. " <" .. lo .. ".." .. hi .. " | auto>") end
            S.over[key] = clamp(v, lo, hi)
        end
        core.engine.print("info", "[dynamic_sky] " .. key .. ":", S.over[key] or "auto")
    end)
    overrides[#overrides + 1] = { key = key, lo = lo, hi = hi }
end
make_override("sky_rain", "rain", 0, 1)
make_override("sky_snow", "snow", 0, 1)
make_override("sky_fog", "fog", 0, 1)
make_override("sky_lightning", "lightning", 0, 1)
make_override("sky_wind", "wind", 0, 6)

-- sky_winddir <deg>: direction the wind blows TOWARDS (0 = +Z, 90 = +X, 180 = -Z, 270 = -X); rain, snow and clouds follow
local function set_wind_dir(deg)
    deg = tonumber(deg) or 0
    S.wdir_t = { sin(rad(deg)), cos(rad(deg)) }
end

util.input.register("sky_winddir", function(args)
    local deg = tonumber(args[1])
    if not deg then
        return core.engine.print("info", util.string.format("[dynamic_sky] wind blows towards (%.2f, %.2f)", S.wdir_t[1], S.wdir_t[2]))
    end
    set_wind_dir(deg)
    core.engine.print("info", "[dynamic_sky] wind direction:", deg, "deg")
end)


------------------
--[[ Exports ]]--
------------------

for _, o in ipairs(overrides) do
    util.export.register("set_" .. o.key, function(v) S.over[o.key] = tonumber(v) and clamp(tonumber(v), o.lo, o.hi) or nil end)
end
util.export.register("set_wind_dir", set_wind_dir)
