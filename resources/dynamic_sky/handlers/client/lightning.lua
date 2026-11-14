----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/lightning.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Thunderstorm strokes and the flash they add to the scene ]]--
----------------------------------------------------------------

local state = Sky.state
local clamp = Math.clamp

-- tiny deterministic PRNG (0..1), so we do not depend on a random() in the sandbox
local function rnd() state.seed = (state.seed * 1664525 + 1013904223) % 4294967296; return state.seed / 4294967296 end

-- a real strike is a quick flicker of strokes (dim leader, one or two bright return strokes, a few
-- weaker restrikes ~40-120 ms apart) followed by a slower afterglow while the cloud is lit from inside.
-- Now and then it is a close strike (very bright, loud) and sometimes only distant sheet lightning (dim, wide).
Sky.on("update", function(F)
    local dt = F.dt
    if state.cur.lightning > 0.3 then
        state.bolt_cd = state.bolt_cd - dt
        if state.bolt_cd <= 0 then
            local kind = rnd()
            local power = kind < 0.14 and 1.55 or (kind < 0.72 and (0.95 + 0.2 * rnd()) or (0.40 + 0.2 * rnd()))   -- close / normal / distant
            local n = 2 + util.math.floor(rnd() * 4.0)                      -- 2..5 strokes
            local t = 0.0
            state.strokes, state.stroke_t = {}, 0.0
            for i = 1, n do
                local amp
                if i == 1 then amp = power * (0.35 + 0.2 * rnd())             -- stepped leader
                elseif i == 2 then amp = power                                  -- main return stroke
                else amp = power * (0.35 + 0.5 * rnd()) end                     -- restrikes
                state.strokes[#state.strokes + 1] = { t = t, a = amp }
                t = t + 0.04 + 0.09 * rnd()
            end
            state.after_peak = power
            state.bolt_cd = (2.5 + rnd() * 9.0) / state.cur.lightning
        end
    end
    if state.strokes and #state.strokes > 0 then
        state.stroke_t = (state.stroke_t or 0.0) + dt
        local i = 1
        while i <= #state.strokes do
            if state.stroke_t >= state.strokes[i].t then
                state.fast = util.math.max(state.fast or 0.0, state.strokes[i].a)
                state.after = util.math.max(state.after or 0.0, (state.after_peak or 1.0) * 0.55)
                util.table.remove(state.strokes, i)
            else
                i = i + 1
            end
        end
        if #state.strokes == 0 then state.strokes, state.stroke_t = nil, 0.0 end
    end
    if not state.strokes then state.stroke_t = 0.0 end
    state.fast  = (state.fast or 0.0) * (0.00002 ^ dt)       -- each stroke dies in ~40 ms
    state.after = (state.after or 0.0) * (0.12 ^ dt)         -- the cloud glows for about a second
    if state.fast < 0.01 then state.fast = 0.0 end
    if state.after < 0.01 then state.after = 0.0 end
    state.flash = util.math.max(state.flash * (0.0004 ^ dt), 0.0)           -- a manual flash decays on its own
    if state.flash < 0.01 then state.flash = 0.0 end
    F.FL = state.flash + (state.fast + 0.32 * state.after) * Config.lightning_intensity     -- effective flash used everywhere else (can exceed 1)
end)


-----------------
--[[ Exports ]]--
-----------------

util.export.register("flash", function(v) state.flash = clamp(tonumber(v) or 1.0, 0.0, 1.0) end)
