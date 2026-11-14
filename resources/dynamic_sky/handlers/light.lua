----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/light.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Scene directional light and ambient environment ]]--
----------------------------------------------------------------

local state = Sky.state
local clamp, lerp3 = Math.clamp, Math.lerp3


--------------
--[[ Init ]]--
--------------

Sky.on("init", function()
    if Config.control_environment then
        gfx.sky.set_mode(gfx.sky.sky_mode.PROCEDURAL)
        gfx.env.set_background_mode(gfx.env.background_mode.SKY)
        gfx.env.set_ambient_source(gfx.env.ambient_source.SKY)
        gfx.env.set_reflection_source(gfx.env.reflection_source.SKY)
        gfx.sky.procedural.set_sun_angle_max(0.0)
    end

    if Config.control_light then
        state.light = light.directional.create()
        state.light:set_position({ 0, 5, 0 })
        state.light:set_shadow_enabled(Config.shadows)
        state.light:set_sky_mode(light.directional.sky_mode.LIGHT_ONLY) -- our shader draws the sun disc
    end
end)


----------------
--[[ Update ]]--
----------------

-- light travels away from the sun / moon
local function aim(l, dir)
    local up = (util.math.abs(dir[2]) > 0.98) and { 0, 0, 1 } or { 0, 1, 0 }
    l:look_at_from_position({ 0, 0, 0 }, { -dir[1] * 10, -dir[2] * 10, -dir[3] * 10 }, up)
end

Sky.on("update", function(F)
    local tc, FL = F.tc, F.FL

    if state.light then
        aim(state.light, F.key_dir)
        local lc = lerp3(Config.night_light.color, tc.light, F.day_w)
        state.light:set_color({ lc[1], lc[2], lc[3], 1.0 })
        state.light:set_energy(F.sun_energy * F.day_w + F.night_energy * 3.0 + FL * 4.5)
    end

    if Config.control_environment then
        local t, h, g = tc.ambient_top, tc.horizon, tc.ground
        -- shadow fill: lift the ambient by a daylight-scaled floor so shaded areas never go black
        -- (sky light bounces around; at sunset the sky colours alone are too dim for that)
        local fl = Config.ambient_floor * clamp(tc.light_energy, 0.0, 1.0) ^ 0.5
        local nw = clamp(1.0 - clamp(tc.light_energy * 1.5, 0.0, 1.0) * (1.0 - clamp(tc.stars, 0.0, 1.0)), 0.0, 1.0)     -- 0 by day .. 1 at night, rising through twilight
        fl = fl + Config.night_ambient_floor * nw     -- night: shadowed ground is dark blue, not pure black
        local fc = Config.ambient_floor_color
        local function lift(c3, k) return { c3[1] + fc[1] * fl * k, c3[2] + fc[2] * fl * k, c3[3] + fc[3] * fl * k } end
        local t2, h2, g2 = lift(t, 1.0), lift(h, 0.8), lift(g, 0.7)
        gfx.sky.procedural.set_sky_top_color({ t2[1], t2[2], t2[3], 1.0 })
        gfx.sky.procedural.set_sky_horizon_color({ h2[1] * 0.8 * F.grey, h2[2] * 0.8 * F.grey, h2[3] * 0.8 * F.grey, 1.0 })
        gfx.sky.procedural.set_ground_horizon_color({ h2[1] * 0.6, h2[2] * 0.6, h2[3] * 0.6, 1.0 })
        gfx.sky.procedural.set_ground_bottom_color({ g2[1], g2[2], g2[3], 1.0 })
        gfx.env.set_ambient_energy(Config.ambient_energy * (1.0 + Config.night_ambient_boost * nw) * (1.0 + FL * 2.4))
    end
end)
