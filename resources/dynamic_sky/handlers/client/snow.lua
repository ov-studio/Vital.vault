----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/snow.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Snowfall: real flakes that collide with the world ]]--
----------------------------------------------------------------

local S = Sky.state
local floor, max, sqrt = util.math.floor, util.math.max, util.math.sqrt
local lerp, clamp = Math.lerp, Math.clamp


----------------
--[[ Init ]]--
----------------

-- flakes vanish on roofs and ground, so nothing snows indoors
Sky.on("init", function()
    if not Config.use_precipitation then return end
    local sh = Sky.shader("files/shaders/snow_fall.gdshader")
    if not sh then return end
    local ok, err = pcall(function()
        local life = Config.snow_life
        S.snow_full = floor(Config.snow_rate * life)
        local car = particle.gpu.create()
        car:set_amount(S.snow_full)
        car:set_lifetime(life)
        car:set_one_shot(false)
        car:set_explosiveness(0.0)
        car:set_randomness(0.0)
        car:set_local_coords(false)
        car:set_emission_shape(particle.gpu.emission_shape.BOX, { 17.0, 0.2, 17.0 })
        car:set_direction({ 0, -1, 0 })
        car:set_spread(0)
        car:set_gravity({ 0, 0, 0 })
        car:set_visibility_aabb({ -30, -30, -30 }, { 60, 60, 60 })
        car:set_material(sh)
        pcall(car.set_collision, car, particle.gpu.collision_mode.HIDE, 0.0, 1.0)      -- older engines: flakes just fall through
        car:set_visible(false)
        S.snow_car, S.snow_shader = car, sh
    end)
    S.snow_on = ok
    if not ok then core.engine.print("warn", "[dynamic_sky] snow particles unavailable: " .. tostring(err)) end
end)


-----------------
--[[ Update ]]--
-----------------

Sky.on("update", function(F)
    S.flt = (S.flt + F.dt) % 50.26548
    if not S.snow_on then return end
    local car, sh, cpos, SN = S.snow_car, S.snow_shader, F.cpos, F.SN
    local dens = Sky.level(car, "snow_lvl", S.snow_full, SN, S.precip and cpos ~= nil and SN > 0.02)
    if not dens then return end

    local fx, fy, fz = F.wx * 0.85, -(0.9 + 0.7 * SN), F.wz * 0.85
    local fl = sqrt(fx * fx + fy * fy + fz * fz)
    pcall(function()
        car:set_global_position({ cpos[1], cpos[2] + 12.0, cpos[3] })
        car:set_direction({ fx / fl, fy / fl, fz / fl })
        car:set_param(particle.gpu.param.VELOCITY, fl * 0.8, fl * 1.2)
    end)
    -- flake colour against the open sky: the scene's colour (horizon tint), kept bright at night so flakes are not dark specks;
    -- in front of scenery the shader takes the colour of what is behind (the ground snow) instead
    local lf = 0.55 + 0.4 * clamp(F.daylight, 0.0, 1.0)
    sh:set_param("fall_vel", { fx, fy, fz })
    sh:set_param("flake_size", Config.snow_size)
    sh:set_param("flutter_t", S.flt)
    sh:set_param("sway", 0.45 / (1.0 + max(S.cur.wind - 1.0, 0.0) * 0.6))
    sh:set_param("density", dens)
    sh:set_param("tint", { lerp(F.pr, 1.0, 0.6) * lf, lerp(F.pg, 1.0, 0.6) * lf, lerp(F.pb, 1.0, 0.6) * lf, 0.85 })
end)
