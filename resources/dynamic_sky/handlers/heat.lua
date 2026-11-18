----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/heat.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 18/11/2026
     Desc: Heat haze over distant ground ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state
local lerp, clamp, smoothstep = util.math.lerp, util.math.clamp, util.math.smoothstep


------------------
--[[ Handlers ]]--
------------------

-- Creates the heat haze shader (a post process screen quad) that makes the hot air over far ground shimmer.
Sky.on("init", function()
    local shader = core.shader.create("files/shaders/heat_haze.gdshader", core.shader.shader_mode.POST_PROCESS)
    shader:set_param("start_dist", Config.heat_distance)
    shader:set_param("amplitude", Config.heat_amplitude)
    shader:set_param("scale", Config.heat_scale)
    state.heat_shader = shader
end)

-- Works out how hot it is (a high sun on a clear, dry day, not over snow) and feeds it into the shader every frame.
Sky.on("update", function(frame)
    local cur = state.cur
    local sun = smoothstep(0.35, 0.75, frame.sun[2])
    local clear = 1.0 - smoothstep(0.15, 0.45, cur.coverage)
    local dry = (1.0 - clamp(cur.rain * 3.0, 0.0, 1.0)) * (1.0 - clamp(cur.snow * 5.0, 0.0, 1.0)) * (1.0 - clamp(cur.fog, 0.0, 1.0))
        * (1.0 - clamp(cur.sand, 0.0, 1.0)) * (1.0 - clamp(state.cover * 2.0, 0.0, 1.0))
    local target = state.heat and Config.heat_strength * sun * clear * dry or 0.0
    state.heat_amt = lerp(state.heat_amt, target, clamp(frame.dt * 0.3, 0.0, 1.0))
    state.heat_shader:set_param("strength", state.heat_amt)
end)

-- Draws the heat haze before the sky, it distorts the scene only and the sky and god rays are drawn over it.
Sky.on("draw", function()
    if not state.enabled or state.heat_amt < 0.01 then return end

    core.engine.draw_material({ 0, 0 }, core.display.get_resolution(), state.heat_shader, 0, { 0, 0 }, { 1, 1, 1, 1 })
end)


------------------
--[[ Commands ]]--
------------------

-- Toggles the heat haze, no argument flips
-- Usage: /sky_heat [on|off]
util.input.register("sky_heat", function(args)
    state.heat = Sky.switch(args[1], state.heat)
    core.engine.print("info", util.string.format("Heat haze %s", state.heat and "on" or "off"))
end)
