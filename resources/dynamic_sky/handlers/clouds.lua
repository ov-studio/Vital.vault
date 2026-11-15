----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/clouds.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Volumetric clouds: noise, low resolution render pass and cloud uniforms ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local floor, max, abs = util.math.floor, util.math.max, util.math.abs
local clamp = Math.clamp


---------------
--[[ Utils ]]--
---------------

local private = {}

-- Sets a cloud pass uniform, the pass is created on the first draw so it may not exist yet.
function private.set_cloud(name, value)
    if state.cloud_sh then state.cloud_sh:set_param(name, value) end
end

-- (Re)creates the cloud shaders and rendertargets for a resolution.
-- The volumetric clouds are marched into a small rendertarget (a fraction of the screen), blurred with two
-- passes (horizontal, vertical) and sky.gdshader reads the result with one texture fetch per pixel.
-- The rendertargets are hdr (16 bit float): the cloud light is above 1 and 8 bits would band.
function private.setup(width, height)
    local w, h = max(64, floor(width / Config.cloud_rt_div)), max(64, floor(height / Config.cloud_rt_div))
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
    state.crt_w, state.crt_h, state.crt_rx, state.crt_ry = w, h, width, height
end


------------------
--[[ Handlers ]]--
------------------

-- Loads the baked cloud noise (see tools/bake_cloud_noise.py), sampled instead of computing noise per pixel.
Sky.on("init", function()
    state.noise = core.image.create("files/textures/cloud_noise.png", true)
end)

-- Marches the volumetric clouds into the low resolution rendertarget and blurs the result, sky.gdshader then reads it.
-- Skipped while the sky is off, and while the camera looks so far down that no pixel can show sky.
Sky.on("draw", function()
    if not state.enabled then return end
    local camera = core.camera.get_active()
    if not camera then return end

    local resolution = core.display.get_resolution()
    local width, height = resolution[1], resolution[2]
    if not state.crt_a or abs(width - state.crt_rx) > 2 or abs(height - state.crt_ry) > 2 then private.setup(width, height) end
    local basis = camera:get_transform().basis
    local tan_half_fov = util.math.tan(util.math.rad(camera:get_fov()) * 0.5)
    local aspect = width / height
    local tan_x, tan_y = tan_half_fov * aspect, tan_half_fov                                          -- the field of view is vertical by default (keep height)
    if camera:get_keep_aspect() == 0 then tan_x, tan_y = tan_half_fov, tan_half_fov / aspect end      -- keep width
    local pitch = util.math.asin(clamp(-basis.z[2], -1.0, 1.0))
    if pitch + util.math.atan(util.math.sqrt(tan_x * tan_x + tan_y * tan_y)) < -0.01 then return end  -- looking far down: nothing to march

    local cloud_pass = state.cloud_sh
    cloud_pass:set_param("cam_x", basis.x)
    cloud_pass:set_param("cam_y", basis.y)
    cloud_pass:set_param("cam_z", basis.z)
    cloud_pass:set_param("cam_pos", camera:get_global_position())
    cloud_pass:set_param("tan_xy", { tan_x, tan_y })
    local target_size = { state.crt_w, state.crt_h }
    core.rendertarget.set_active(state.crt_a, true)
    core.engine.draw_material({ 0, 0 }, target_size, cloud_pass, 0, { 0, 0 }, { 1, 1, 1, 1 })
    core.rendertarget.set_active(nil)
    if Config.cloud_blur then
        core.rendertarget.set_active(state.crt_b, true)
        core.engine.draw_material({ 0, 0 }, target_size, state.cblur_h, 0, { 0, 0 }, { 1, 1, 1, 1 })
        core.rendertarget.set_active(nil)
        core.rendertarget.set_active(state.crt_c, true)
        core.engine.draw_material({ 0, 0 }, target_size, state.cblur_v, 0, { 0, 0 }, { 1, 1, 1, 1 })
        core.rendertarget.set_active(nil)
    end
end)

-- Feeds the time of day, weather, lightning and quality setting into the cloud pass uniforms every frame.
Sky.on("update", function(frame)
    local cycle = frame.cycle
    local quality = Config.qualities[state.quality] or Config.qualities.medium
    local light_color = {
        cycle.light[1] * frame.sun_energy * 1.6 * frame.day_weight + Config.night_light.color[1] * frame.night_energy * 2.0,
        cycle.light[2] * frame.sun_energy * 1.6 * frame.day_weight + Config.night_light.color[2] * frame.night_energy * 2.0,
        cycle.light[3] * frame.sun_energy * 1.6 * frame.day_weight + Config.night_light.color[3] * frame.night_energy * 2.0
    }
    private.set_cloud("horizon_color", cycle.horizon)
    private.set_cloud("haze_density", 0.000012 * (1.0 + state.cur.haze * 5.0))
    private.set_cloud("light_dir", frame.key_dir)
    private.set_cloud("light_color", light_color)

    local night_glow = Config.night_cloud_glow
    local night_factor = clamp(cycle.stars, 0.0, 1.0) * (0.35 + 0.65 * state.cur.dark)
    private.set_cloud("cloud_ambient_top", {
        cycle.ambient_top[1] * frame.cloud_grey + night_glow[1] * night_factor + frame.flash * 2.2,
        cycle.ambient_top[2] * frame.cloud_grey + night_glow[2] * night_factor + frame.flash * 2.4,
        cycle.ambient_top[3] * frame.cloud_grey + night_glow[3] * night_factor + frame.flash * 3.2
    })
    private.set_cloud("cloud_ambient_bottom", {
        cycle.ambient_bottom[1] + night_glow[1] * night_factor * 0.6,
        cycle.ambient_bottom[2] + night_glow[2] * night_factor * 0.6,
        cycle.ambient_bottom[3] + night_glow[3] * night_factor * 0.6
    })

    local coverage = state.clouds and state.cur.coverage or 0.0
    state.shader:set_param("cloud_coverage", coverage)
    private.set_cloud("cloud_coverage", coverage)
    private.set_cloud("cloud_density", state.cur.density)
    private.set_cloud("cloud_type", state.cur.type)
    private.set_cloud("cloud_base", Config.cloud_base)
    private.set_cloud("cloud_thickness", Config.cloud_thickness)
    private.set_cloud("cloud_scale", Config.cloud_scale)
    private.set_cloud("cloud_detail", Config.cloud_detail)
    private.set_cloud("cloud_steps", quality.steps)
    private.set_cloud("cloud_light_steps", quality.light)
    private.set_cloud("wind_offset", state.wind)
    private.set_cloud("cloud_time", state.cloud_t)
end)


------------------
--[[ Commands ]]--
------------------

-- Sets the cloud quality, trading fps for detail
-- Usage: /sky_quality <low|medium|high|ultra>
util.input.register("sky_quality", function(args)
    if not Config.qualities[args[1] or ""] then return core.engine.print("warn", "Usage: sky_quality <low|medium|high|ultra>") end
    state.quality = args[1]
    core.engine.print("info", "[dynamic_sky] cloud quality", state.quality)
end)

-- Toggles the volumetric clouds, no argument flips
-- Usage: /sky_clouds [on|off]
util.input.register("sky_clouds", function(args)
    state.clouds = Sky.switch(args[1], state.clouds)
    core.engine.print("info", "[dynamic_sky] clouds:", state.clouds and "on" or "off")
end)
