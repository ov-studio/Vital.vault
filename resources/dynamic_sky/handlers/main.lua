----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: handlers/main.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Runs every handler: init once, then update and draw each frame ]]--
----------------------------------------------------------------

--TODO: Improve

-------------------
--[[ Variables ]]--
-------------------

local state = Sky.state


------------------
--[[ Handlers ]]--
------------------

Sky.run("init")

util.event.on("sandbox:process", function(dt)
    if not state.enabled then return end
    Sky.run("update", { dt = dt })
end)

util.event.on("sandbox:draw", function()
    Sky.run("draw")
end)
