----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/fog.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Scene fog from the weather ]]--
----------------------------------------------------------------

local state = Sky.state


-- fog, rain, blizzard, sandstorm ...
Sky.on("update", function(F)
    if not (Config.use_fog and gfx.fog) then return end
    local fg = state.cur.fog
    local want = fg > 0.01
    if want ~= state.fog_on then
        pcall(gfx.fog.set_enabled, want)
        if want then pcall(gfx.fog.set_sky_affect, 0.0) end     -- our sky shader does its own haze
        state.fog_on = want
    end
    if want then
        -- the horizon colour already carries the time of day (dark blue at night), so it is used as is
        local h = F.tc.horizon
        local k = 0.85 * (1.0 - 0.35 * state.cur.dark)
        pcall(gfx.fog.set_density, fg * Config.fog_density_max)
        pcall(gfx.fog.set_light_color, { h[1] * k, h[2] * k, h[3] * k, 1.0 })
        pcall(gfx.fog.set_light_energy, 1.0 + F.FL * 3.2)
    end
end)
