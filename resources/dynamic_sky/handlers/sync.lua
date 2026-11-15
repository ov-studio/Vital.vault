----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/sync.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Authoritative clock and weather, synced to every client ]]--
----------------------------------------------------------------

--TODO: Improve

-------------------
--[[ Variables ]]--
-------------------

local state = {
    time    = Config.start_time,              -- hour of day, 0..24
    day     = 0,                              -- day counter (moon phase)
    scale   = 1.0,                            -- timescale multiplier
    weather = Config.default_weather,
}
local last_tick = core.engine.get_tick()


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Returns the length of a full day in seconds, 0 when the clock is frozen.
function private.day_seconds()
    if Config.day_length_min <= 0 then return 0 end
    return Config.day_length_min * 60.0
end

-- Advances the server clock by the real time passed since the last call.
function private.advance()
    local now = core.engine.get_tick()
    local dt = (now - last_tick) / 1000.0
    last_tick = now
    local ds = private.day_seconds()
    if ds <= 0 or state.scale == 0 then return end
    state.time = state.time + dt * state.scale * (24.0 / ds)
    while state.time >= 24.0 do
        state.time = state.time - 24.0
        state.day = state.day + 1
    end
    while state.time < 0 do
        state.time = state.time + 24.0
        state.day = util.math.max(0, state.day - 1)
    end
end

-- Sends the current time, day, timescale and weather to every client, or only to one peer.
function private.push(peer)
    private.advance()
    local opts = { remote = true }
    if peer then opts.peer = peer end
    util.event.emit("dynamic_sky:sync", opts, state.time, state.day, state.scale, state.weather)
end

-- Sets the hour of the day (0-24) and syncs it to the clients.
-- Returns false if the value is not a number.
function private.set_time(hour)
    hour = tonumber(hour)
    if not hour then return false end

    private.advance()
    state.time = hour % 24.0
    private.push()
    return true
end

-- Sets the weather preset by name and syncs it to the clients.
-- Returns false if the preset does not exist.
function private.set_weather(name)
    if not Config.weather[name] then return false end
    state.weather = name
    private.push()
    return true
end

-- Sets the timescale multiplier (0-1000, 0 freezes the time) and syncs it to the clients.
-- Returns false if the value is not a number.
function private.set_timescale(scale)
    scale = tonumber(scale)
    if not scale then return false end
    private.advance()
    state.scale = util.math.max(0.0, util.math.min(scale, 1000.0))
    private.push()
    return true
end


------------------
--[[ Handlers ]]--
------------------

core.engine.print("info", "[dynamic_sky] server clock started at", state.time)

util.timer.create(function()
    private.push()
end, Config.sync_interval_ms, 0)

util.event.on("dynamic_sky:request", function(kind, value)
    if not Config.allow_client_control then return end
    if kind == "time" then private.set_time(value)
    elseif kind == "weather" then private.set_weather(tostring(value))
    elseif kind == "timescale" then private.set_timescale(value) end
end, { remote = true })

util.event.on("peer:resource:started", function(peer_id, resource)
    if resource ~= util.resource.current() then return false end
    private.push(peer_id)
end)


-----------------
--[[ Exports ]]--
-----------------

-- Public API surface exposed to other server scripts and resources: read the clock,
-- set the time, weather and timescale.
util.export.register("get_time", function()
    private.advance()
    return state.time
end)
util.export.register("set_time", private.set_time)
util.export.register("set_weather", private.set_weather)
util.export.register("set_timescale", private.set_timescale)
