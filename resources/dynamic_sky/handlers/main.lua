----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/main.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Runs every handler: init once, then update and draw each frame ]]--
----------------------------------------------------------------


-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state


------------------
--[[ Handlers ]]--
------------------

-- Runs every init handler once, in manifest order.
Sky.run("init")

-- Runs every update handler each frame with the frame time, while the sky is enabled.
util.event.on("sandbox:process", function(dt)
    if not state.enabled then return end
    
    Sky.run("update", { dt = dt })
end)

-- Runs every draw handler each frame.
util.event.on("sandbox:draw", function()
    Sky.run("draw")
end)
