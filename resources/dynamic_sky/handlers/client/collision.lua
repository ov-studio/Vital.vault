----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/client/collision.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: World collider for the rain and snow particles ]]--
----------------------------------------------------------------

local S = Sky.state


-- the world collider re-renders the level from above every time it moves, so it only exists while rain or snow is falling
-- (and a few seconds after, for the last particles in the air)
Sky.on("update", function(F)
    local need = (S.gpu_lvl or 0) > 0 or (S.snow_lvl or 0) > 0
    S.col_idle = need and 0.0 or (S.col_idle or 0.0) + F.dt
    local want = need or S.col_idle < 8.0
    if want ~= (S.col_on or false) and particle.gpu.set_world_collision then
        S.col_on = want
        pcall(particle.gpu.set_world_collision, want, { 48, 60, 48 }, Config.splash_gpu_res)
    end
end)
