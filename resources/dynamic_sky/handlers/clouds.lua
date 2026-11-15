----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/clouds.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Volumetric clouds: noise, low resolution render pass and cloud uniforms ]]--
----------------------------------------------------------------

--TODO: Improve

-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local floor, max, abs = util.math.floor, util.math.max, util.math.abs
local clamp = Math.clamp


--------------
--[[ Init ]]--
--------------

-- baked cloud noise (see tools/bake_cloud_noise.py), sampled instead of computing noise per pixel
Sky.on("init", function()
    state.noise = core.image.create("files/textures/cloud_noise.png", true)
end)


---------------
--[[ Pass ]]--
---------------

-- the volumetric clouds are marched into a small rendertarget (a fraction of the screen), blurred with two cheap
-- passes (horizontal, vertical) and sky.gdshader reads the result with one texture fetch per pixel.
-- The rendertargets are hdr (16 bit float): the cloud light is above 1 and 8 bits would band.
local function setup(rx, ry)
    local div = Config.cloud_rt_div
    local w, h = max(64, floor(rx / div)), max(64, floor(ry / div))
    if not state.cloud_sh then
        local mode = core.shader.shader_mode.CANVAS_ITEM
        state.cloud_sh = core.shader.create("files/shaders/cloud_pass.gdshader", mode)
        state.cblur_h = core.shader.create("files/shaders/cloud_blur.gdshader", mode)
        state.cblur_v = core.shader.create("files/shaders/cloud_blur.gdshader", mode)
        state.cloud_sh:set_param("noise_tex", state.noise)
    end
    -- a resize makes new rendertargets, the old ones are freed
    for _, rt in ipairs({ state.crt_a, state.crt_b, state.crt_c }) do rt:destroy() end
    -- every rendertarget gets ONE draw per frame: it is rendered once, with everything drawn to it
    state.crt_a = core.rendertarget.create({ w, h }, true, true)
    state.crt_b = core.rendertarget.create({ w, h }, true, true)
    state.crt_c = core.rendertarget.create({ w, h }, true, true)
    state.cblur_h:set_param("src", state.crt_a)
    state.cblur_h:set_param("step_uv", { 1.0 / w, 0.0 })
    state.cblur_v:set_param("src", state.crt_b)
    state.cblur_v:set_param("step_uv", { 0.0, 1.0 / h })
    state.shader:set_param("cloud_tex", Config.cloud_blur and state.crt_c or state.crt_a)
    state.crt_w, state.crt_h, state.crt_rx, state.crt_ry = w, h, rx, ry
end

Sky.on("draw", function()
    if not state.enabled then return end
    local cam = core.camera.get_active()
    if not cam then return end
    local res = core.display.get_resolution()
    local rx, ry = res[1], res[2]
    if not state.crt_a or abs(rx - state.crt_rx) > 2 or abs(ry - state.crt_ry) > 2 then setup(rx, ry) end

    local basis = cam:get_transform().basis
    local bx, by, bz = basis.x, basis.y, basis.z
    local pos = cam:get_global_position()
    local t = util.math.tan(util.math.rad(cam:get_fov()) * 0.5)
    local aspect = rx / ry
    local tx, ty = t * aspect, t                            -- the field of view is vertical by default (keep height)
    if cam:get_keep_aspect() == 0 then tx, ty = t, t / aspect end    -- keep width

    -- looking far down: no pixel of the screen can show sky, so nothing to march
    local pitch = util.math.asin(clamp(-bz[2], -1.0, 1.0))
    if pitch + util.math.atan(util.math.sqrt(tx * tx + ty * ty)) < -0.01 then return end

    local cs = state.cloud_sh
    cs:set_param("cam_x", bx)
    cs:set_param("cam_y", by)
    cs:set_param("cam_z", bz)
    cs:set_param("cam_pos", pos)
    cs:set_param("tan_xy", { tx, ty })

    local size = { state.crt_w, state.crt_h }
    core.rendertarget.set_active(state.crt_a, true)
    core.engine.draw_material({ 0, 0 }, size, cs, 0, { 0, 0 }, { 1, 1, 1, 1 })
    core.rendertarget.set_active(nil)
    if Config.cloud_blur then
        core.rendertarget.set_active(state.crt_b, true)
        core.engine.draw_material({ 0, 0 }, size, state.cblur_h, 0, { 0, 0 }, { 1, 1, 1, 1 })
        core.rendertarget.set_active(nil)
        core.rendertarget.set_active(state.crt_c, true)
        core.engine.draw_material({ 0, 0 }, size, state.cblur_v, 0, { 0, 0 }, { 1, 1, 1, 1 })
        core.rendertarget.set_active(nil)
    end
end)


----------------
--[[ Update ]]--
----------------

Sky.on("update", function(F)
    local csh = state.cloud_sh                                  -- the cloud pass is created on the first draw
    local function cset(name, v)                            -- cloud values: only the cloud pass uses them
        if csh then csh:set_param(name, v) end
    end
    local tc, FL = F.tc, F.FL
    local q = Config.qualities[state.quality] or Config.qualities.medium

    local cloud_light = {
        tc.light[1] * F.sun_energy * 1.6 * F.day_w + Config.night_light.color[1] * F.night_energy * 2.0,
        tc.light[2] * F.sun_energy * 1.6 * F.day_w + Config.night_light.color[2] * F.night_energy * 2.0,
        tc.light[3] * F.sun_energy * 1.6 * F.day_w + Config.night_light.color[3] * F.night_energy * 2.0,
    }
    cset("horizon_color", tc.horizon)
    cset("haze_density", 0.000012 * (1.0 + state.cur.haze * 5.0))
    cset("light_dir", F.key_dir)
    cset("light_color", cloud_light)

    -- night: clouds still catch scattered moon / sky glow, so an overcast or rainy night is dim grey-blue, not pitch black
    local ng = Config.night_cloud_glow
    local nk = clamp(tc.stars, 0.0, 1.0) * (0.35 + 0.65 * state.cur.dark)
    cset("cloud_ambient_top", { tc.ambient_top[1] * F.grey + ng[1] * nk + FL * 2.2, tc.ambient_top[2] * F.grey + ng[2] * nk + FL * 2.4, tc.ambient_top[3] * F.grey + ng[3] * nk + FL * 3.2 })
    cset("cloud_ambient_bottom", { tc.ambient_bottom[1] + ng[1] * nk * 0.6, tc.ambient_bottom[2] + ng[2] * nk * 0.6, tc.ambient_bottom[3] + ng[3] * nk * 0.6 })

    local coverage = state.clouds and state.cur.coverage or 0.0
    state.shader:set_param("cloud_coverage", coverage)
    cset("cloud_coverage", coverage)
    cset("cloud_density", state.cur.density)
    cset("cloud_type", state.cur.type)
    cset("cloud_base", Config.cloud_base)
    cset("cloud_thickness", Config.cloud_thickness)
    cset("cloud_scale", Config.cloud_scale)
    cset("cloud_detail", Config.cloud_detail)
    cset("cloud_steps", q.steps)
    cset("cloud_light_steps", q.light)
    cset("wind_offset", state.wind)
    cset("cloud_time", state.cloud_t)
end)


-----------------
--[[ Input ]]--
-----------------

-- sky_quality low|medium|high|ultra   (client side, fps vs. cloud quality)
util.input.register("sky_quality", function(args)
    if not Config.qualities[args[1] or ""] then return core.engine.print("warn", "Usage: sky_quality <low|medium|high|ultra>") end
    state.quality = args[1]
    core.engine.print("info", "[dynamic_sky] cloud quality", state.quality)
end)

-- sky_clouds on|off : toggle the clouds (no argument = flip)
util.input.register("sky_clouds", function(args)
    state.clouds = Sky.switch(args[1], state.clouds)
    core.engine.print("info", "[dynamic_sky] clouds:", state.clouds and "on" or "off")
end)
