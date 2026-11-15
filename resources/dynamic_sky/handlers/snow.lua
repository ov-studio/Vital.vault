----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/snow.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Snowfall: real flakes that collide with the world ]]--
----------------------------------------------------------------

--TODO: Improve

-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local floor, max, sqrt = util.math.floor, util.math.max, util.math.sqrt
local lerp, clamp = Math.lerp, Math.clamp


------------------
--[[ Handlers ]]--
------------------

-- flakes vanish on roofs and ground, so nothing snows indoors
Sky.on("init", function()
    if not Config.use_precipitation then return end
    local sh = core.shader.create("files/shaders/snow_fall.gdshader", core.shader.shader_mode.SPATIAL)
    state.snow_full = floor(Config.snow_rate * Config.snow_life)
    local emitter = particle.gpu.create()
    emitter:set_amount(state.snow_full)
    emitter:set_lifetime(Config.snow_life)
    emitter:set_one_shot(false)
    emitter:set_explosiveness(0.0)
    emitter:set_randomness(0.0)
    emitter:set_local_coords(false)
    emitter:set_emission_shape(particle.gpu.emission_shape.BOX, { 17.0, 0.2, 17.0 })
    emitter:set_direction({ 0, -1, 0 })
    emitter:set_spread(0)
    emitter:set_gravity({ 0, 0, 0 })
    emitter:set_visibility_aabb({ -30, -30, -30 }, { 60, 60, 60 })
    emitter:set_material(sh)
    emitter:set_collision(particle.gpu.collision_mode.HIDE, 0.0, 1.0)
    emitter:set_visible(false)
    state.snow_emitter, state.snow_shader = emitter, sh
    state.snow_on = true
end)

Sky.on("update", function(F)
    state.flt = (state.flt + F.dt) % 50.26548
    if not state.snow_on then return end

    local emitter, sh, cpos, SN = state.snow_emitter, state.snow_shader, F.cpos, F.SN
    local dens = Sky.level(emitter, "snow_lvl", state.snow_full, SN, state.precip and cpos ~= nil and SN > 0.02)
    if not dens then return end
    local fx, fy, fz = F.wx * 0.85, -(0.9 + 0.7 * SN), F.wz * 0.85
    local fl = sqrt(fx * fx + fy * fy + fz * fz)
    emitter:set_global_position({ cpos[1], cpos[2] + 12.0, cpos[3] })
    emitter:set_direction({ fx / fl, fy / fl, fz / fl })
    emitter:set_param(particle.gpu.param.VELOCITY, fl * 0.8, fl * 1.2)

    -- flake colour against the open sky: the scene's colour (horizon tint), kept bright at night so flakes are not dark specks;
    -- in front of scenery the shader takes the colour of what is behind (the ground snow) instead
    local lf = 0.55 + 0.4 * clamp(F.daylight, 0.0, 1.0)
    sh:set_param("fall_vel", { fx, fy, fz })
    sh:set_param("flake_size", Config.snow_size)
    sh:set_param("flutter_t", state.flt)
    sh:set_param("sway", 0.45 / (1.0 + max(state.cur.wind - 1.0, 0.0) * 0.6))
    sh:set_param("density", dens)
    sh:set_param("tint", { lerp(F.pr, 1.0, 0.6) * lf, lerp(F.pg, 1.0, 0.6) * lf, lerp(F.pb, 1.0, 0.6) * lf, 0.85 })
end)
