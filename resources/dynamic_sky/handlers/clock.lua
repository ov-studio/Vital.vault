----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/clock.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Local clock, server sync and time commands ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Asks the server to change the time, weather or timescale, the server owns all three.
function private.request(kind, value) 
    util.event.emit("dynamic_sky:request", { remote = true }, kind, value) 
end


------------------
--[[ Handlers ]]--
------------------

-- Advances the local clock every frame (scaled by the timescale), the server sync corrects any drift.
Sky.on("update", function(frame)
    if Config.day_length_min > 0 and state.scale > 0 then
        state.time = state.time + frame.dt * state.scale * (24.0 / (Config.day_length_min * 60.0))
        if state.time >= 24 then state.time = state.time - 24; state.day = state.day + 1 end
    end
end)

-- Applies the time, day, timescale and weather the server sends on join and periodically.
util.event.on("dynamic_sky:sync", function(time, day, scale, weather)
    state.time, state.day, state.scale = time, day, scale
    if Config.weather[weather] then state.weather = weather end
end)


-----------------
--[[ Exports ]]--
-----------------

-- Public API surface exposed to other resources: read the current time and weather.
util.export.register("get_time", function() return state.time end)
util.export.register("get_weather", function() return state.weather end)


------------------
--[[ Commands ]]--
------------------

-- Requests a new time of day from the server
-- Usage: /time <hour | HH:MM>
util.input.register("time", function(args)
    local a = args[1]
    if not a then return core.engine.print("info", util.string.format("[dynamic_sky] time %.2f, weather %s", state.time, state.weather)) end
    local hours, minutes = tostring(a):match("^(%d+):(%d+)$")
    local v = hours and (tonumber(hours) + tonumber(minutes) / 60) or tonumber(a)
    if not v then return core.engine.print("warn", "Usage: time <hour 0-24 | HH:MM>") end
    private.request("time", v)
end)

-- Requests a weather preset from the server
-- Usage: /weather <preset>
util.input.register("weather", function(args)
    if not args[1] or not Config.weather[args[1]] then
        local names = {}
        for n in pairs(Config.weather) do names[#names + 1] = n end
        return core.engine.print("warn", "Usage: weather <" .. util.table.concat(names, "|") .. ">")
    end
    private.request("weather", args[1])
end)

-- Requests a new timescale from the server, 0 freezes the time
-- Usage: /timescale <multiplier>
util.input.register("timescale", function(args)
    if not tonumber(args[1]) then return core.engine.print("warn", "Usage: timescale <multiplier, 0 = freeze>") end
    private.request("timescale", tonumber(args[1]))
end)
