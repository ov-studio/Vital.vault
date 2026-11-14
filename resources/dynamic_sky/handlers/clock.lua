----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/clock.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Local clock, server sync and the time / weather / timescale commands ]]--
----------------------------------------------------------------

local state = Sky.state


----------------
--[[ Clock ]]--
----------------

-- local clock, corrected by server syncs
Sky.on("update", function(F)
    if Config.day_length_min > 0 and state.scale > 0 then
        state.time = state.time + F.dt * state.scale * (24.0 / (Config.day_length_min * 60.0))
        if state.time >= 24 then state.time = state.time - 24; state.day = state.day + 1 end
    end
end)

util.event.on("dynamic_sky:sync", function(time, day, scale, weather)
    state.time, state.day, state.scale = time, day, scale
    if Config.weather[weather] then state.weather = weather end
end)


----------------
--[[ Input ]]--
----------------

-- the server owns time, weather and timescale
local function request(kind, value) util.event.emit("dynamic_sky:request", { remote = true }, kind, value) end

-- time 18.5   or   time 18:30
util.input.register("time", function(args)
    local a = args[1]
    if not a then return core.engine.print("info", util.string.format("[dynamic_sky] time %.2f, weather %s", state.time, state.weather)) end
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


-----------------
--[[ Exports ]]--
-----------------

util.export.register("get_time", function() return state.time end)
util.export.register("get_weather", function() return state.weather end)
