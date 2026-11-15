----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/fog.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Scene fog from the weather ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state


------------------
--[[ Handlers ]]--
------------------

Sky.on("update", function(F)
    if not Config.use_fog then return end
    local want = state.cur.fog > 0.01
    if want ~= state.fog_on then
        gfx.fog.set_enabled(want)
        if want then gfx.fog.set_sky_affect(0.0) end     -- our sky shader does its own haze
        state.fog_on = want
    end
    if want then
        -- the horizon colour already carries the time of day (dark blue at night), so it is used as is
        local k = 0.85 * (1.0 - 0.35 * state.cur.dark)
        gfx.fog.set_density(state.cur.fog * Config.fog_density_max)
        gfx.fog.set_light_color({ F.tc.horizon[1] * k, F.tc.horizon[2] * k, F.tc.horizon[3] * k, 1.0 })
        gfx.fog.set_light_energy(1.0 + F.FL * 3.2)
    end
end)
