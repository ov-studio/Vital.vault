----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/fog.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Engine fog from the weather ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state


------------------
--[[ Handlers ]]--
------------------

-- Switches the engine fog on for fog, rain, blizzard, sandstorm... and sets its density, colour (the horizon) and
-- brightness (lit by lightning) every frame.
Sky.on("update", function(frame)
    if not Config.use_fog then return end

    local wanted = state.cur.fog > 0.01
    if wanted ~= state.fog_on then
        gfx.fog.set_enabled(wanted)
        if wanted then gfx.fog.set_sky_affect(0.0) end  -- our sky shader does its own haze
        state.fog_on = wanted
    end
    
    if wanted then
        -- the horizon colour already carries the time of day (dark blue at night), so it is used as is
        local brightness = 0.85 * (1.0 - 0.35 * state.cur.dark)
        gfx.fog.set_density(state.cur.fog * Config.fog_density_max)
        gfx.fog.set_light_color({ frame.cycle.horizon[1] * brightness, frame.cycle.horizon[2] * brightness, frame.cycle.horizon[3] * brightness, 1.0 })
        gfx.fog.set_light_energy(1.0 + frame.flash * 3.2)
    end
end)
