----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/clock.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Local clock, server sync and the time / weather / timescale commands ]]--
----------------------------------------------------------------

local S = Sky.state


----------------
--[[ Clock ]]--
----------------

-- local clock, corrected by server syncs
Sky.on("update", function(F)
    if Config.day_length_min > 0 and S.scale > 0 then
        S.time = S.time + F.dt * S.scale * (24.0 / (Config.day_length_min * 60.0))
        if S.time >= 24 then S.time = S.time - 24; S.day = S.day + 1 end
    end
end)

util.event.on("dynamic_sky:sync", function(time, day, scale, weather)
    S.time, S.day, S.scale = time, day, scale
    if Config.weather[weather] then S.weather = weather end
end)


----------------
--[[ Input ]]--
----------------

-- the server owns time, weather and timescale
local function request(kind, value) util.event.emit("dynamic_sky:request", { remote = true }, kind, value) end

-- time 18.5   or   time 18:30
util.input.register("time", function(args)
    local a = args[1]
    if not a then return core.engine.print("info", util.string.format("[dynamic_sky] time %.2f, weather %s", S.time, S.weather)) end
    local h, m = tostring(a):match("^(%d+):(%d+)$")
    local v = h and (tonumber(h) + tonumber(m) / 60) or tonumber(a)
    if not v then return core.engine.print("warn", "Usage: time <hour 0-24 | HH:MM>") end
    request("time", v)
end)

util.input.register("weather", function(args)
    if not args[1] or not Config.weather[args[1]] then
        local names = {}
        for n in pairs(Config.weather) do names[#names + 1] = n end
        return core.engine.print("warn", "Usage: weather <" .. util.table.concat(names, "|") .. ">")
    end
    request("weather", args[1])
end)

util.input.register("timescale", function(args)
    if not tonumber(args[1]) then return core.engine.print("warn", "Usage: timescale <multiplier, 0 = freeze>") end
    request("timescale", tonumber(args[1]))
end)


------------------
--[[ Exports ]]--
------------------

util.export.register("get_time", function() return S.time end)
util.export.register("get_weather", function() return S.weather end)
