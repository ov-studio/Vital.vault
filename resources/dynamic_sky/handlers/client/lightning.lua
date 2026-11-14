----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/lightning.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Thunderstorm strokes and the flash they add to the scene ]]--
----------------------------------------------------------------

local S = Sky.state
local clamp = Math.clamp

-- tiny deterministic PRNG (0..1), so we do not depend on a random() in the sandbox
local function rnd() S.seed = (S.seed * 1664525 + 1013904223) % 4294967296; return S.seed / 4294967296 end

-- a real strike is a quick flicker of strokes (dim leader, one or two bright return strokes, a few
-- weaker restrikes ~40-120 ms apart) followed by a slower afterglow while the cloud is lit from inside.
-- Now and then it is a close strike (very bright, loud) and sometimes only distant sheet lightning (dim, wide).
Sky.on("update", function(F)
    local dt = F.dt
    if S.cur.lightning > 0.3 then
        S.bolt_cd = S.bolt_cd - dt
        if S.bolt_cd <= 0 then
            local kind = rnd()
            local power = kind < 0.14 and 1.55 or (kind < 0.72 and (0.95 + 0.2 * rnd()) or (0.40 + 0.2 * rnd()))   -- close / normal / distant
            local n = 2 + util.math.floor(rnd() * 4.0)                      -- 2..5 strokes
            local t = 0.0
            S.strokes, S.stroke_t = {}, 0.0
            for i = 1, n do
                local amp
                if i == 1 then amp = power * (0.35 + 0.2 * rnd())             -- stepped leader
                elseif i == 2 then amp = power                                  -- main return stroke
                else amp = power * (0.35 + 0.5 * rnd()) end                     -- restrikes
                S.strokes[#S.strokes + 1] = { t = t, a = amp }
                t = t + 0.04 + 0.09 * rnd()
            end
            S.after_peak = power
            S.bolt_cd = (2.5 + rnd() * 9.0) / S.cur.lightning
        end
    end
    if S.strokes and #S.strokes > 0 then
        S.stroke_t = (S.stroke_t or 0.0) + dt
        local i = 1
        while i <= #S.strokes do
            if S.stroke_t >= S.strokes[i].t then
                S.fast = util.math.max(S.fast or 0.0, S.strokes[i].a)
                S.after = util.math.max(S.after or 0.0, (S.after_peak or 1.0) * 0.55)
                util.table.remove(S.strokes, i)
            else
                i = i + 1
            end
        end
        if #S.strokes == 0 then S.strokes, S.stroke_t = nil, 0.0 end
    end
    if not S.strokes then S.stroke_t = 0.0 end
    S.fast  = (S.fast or 0.0) * (0.00002 ^ dt)       -- each stroke dies in ~40 ms
    S.after = (S.after or 0.0) * (0.12 ^ dt)         -- the cloud glows for about a second
    if S.fast < 0.01 then S.fast = 0.0 end
    if S.after < 0.01 then S.after = 0.0 end
    S.flash = util.math.max(S.flash * (0.0004 ^ dt), 0.0)           -- a manual flash decays on its own
    if S.flash < 0.01 then S.flash = 0.0 end
    F.FL = S.flash + (S.fast + 0.32 * S.after) * Config.lightning_intensity     -- effective flash used everywhere else (can exceed 1)
end)


------------------
--[[ Exports ]]--
------------------

util.export.register("flash", function(v) S.flash = clamp(tonumber(v) or 1.0, 0.0, 1.0) end)
