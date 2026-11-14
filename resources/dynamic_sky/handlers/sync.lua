----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/sync.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Authoritative clock and weather, synced to every client ]]--
----------------------------------------------------------------

local state = {
    time    = Config.start_time,                 -- hour of day, 0..24
    day     = 0,                              -- day counter (moon phase)
    scale   = 1.0,                            -- timescale multiplier
    weather = Config.default_weather,
}
local last_tick = core.engine.get_tick()

local function day_seconds()
    if Config.day_length_min <= 0 then return 0 end
    return Config.day_length_min * 60.0
end

local function advance()
    local now = core.engine.get_tick()
    local dt = (now - last_tick) / 1000.0
    last_tick = now
    local ds = day_seconds()
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

local function push(peer)
    advance()
    local opts = { remote = true }
    if peer then opts.peer = peer end
    util.event.emit("dynamic_sky:sync", opts, state.time, state.day, state.scale, state.weather)
end

-- late joiners
util.event.on("peer:resource:started", function(peer_id, resource)
    if resource ~= util.resource.current() then return false end
    push(peer_id)
end)

-- periodic drift correction
util.timer.create(function() push() end, Config.sync_interval_ms, 0)

-- exports for other server scripts / resources ------------------------
local function set_time(hour)
    hour = tonumber(hour); if not hour then return false end
    advance()
    state.time = hour % 24.0
    push(); return true
end

local function set_weather(name)
    if not Config.weather[name] then return false end
    state.weather = name; push(); return true
end

local function set_timescale(scale)
    scale = tonumber(scale); if not scale then return false end
    advance(); state.scale = util.math.max(0.0, util.math.min(scale, 1000.0)); push(); return true
end

util.export.register("get_time", function() advance(); return state.time end)
util.export.register("set_time", set_time)
util.export.register("set_weather", set_weather)
util.export.register("set_timescale", set_timescale)

-- client requests (/time /weather /timescale) --------------------------
util.event.on("dynamic_sky:request", function(kind, value)
    if not Config.allow_client_control then return end
    if kind == "time" then set_time(value)
    elseif kind == "weather" then set_weather(tostring(value))
    elseif kind == "timescale" then set_timescale(value) end
end, { remote = true })

core.engine.print("info", "[dynamic_sky] server clock started at", state.time)
