----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/contrails.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 17/11/2026
     Desc: Aircraft and their fading contrails ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local clamp, lerp = util.math.clamp, util.math.lerp


------------------
--[[ Handlers ]]--
------------------

-- The shader flies the aircraft, this hands it the settings once.
Sky.on("init", function()
    state.shader:set_param("contrail_planes", clamp(Config.contrail_planes, 1, 4))
    state.shader:set_param("contrail_height", Config.contrail_height)
    state.shader:set_param("contrail_speed", Config.contrail_speed)
    state.shader:set_param("contrail_life", Config.contrail_life)
end)

-- Hands the shader the flight time (wraps every hour, the flight cycles divide it) and how visible the trails are: they
-- fade out in rain, snow, sand and fog and come back slowly afterwards.
Sky.on("update", function(frame)
    local cur = state.cur
    local target = state.contrails and Config.contrail_strength * (1.0 - clamp(cur.rain * 3.0, 0.0, 1.0)) * (1.0 - clamp(cur.snow * 2.0, 0.0, 1.0))
        * (1.0 - clamp(cur.sand * 2.0, 0.0, 1.0)) * (1.0 - clamp(cur.fog, 0.0, 1.0)) or 0.0
    state.contrail_amt = lerp(state.contrail_amt, target, clamp(frame.dt * 0.5, 0.0, 1.0))
    state.shader:set_param("contrail_time", state.cloud_t % 3600.0)
    state.shader:set_param("contrail_amount", state.contrail_amt)
end)


------------------
--[[ Commands ]]--
------------------

-- Toggles the aircraft and their contrails, no argument flips
-- Usage: /sky_contrails [on|off]
util.input.register("sky_contrails", function(args)
    state.contrails = Sky.switch(args[1], state.contrails)
    core.engine.print("info", util.string.format("Contrails %s", state.contrails and "on" or "off"))
end)
