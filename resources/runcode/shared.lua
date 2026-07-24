----------------------------------------------------------------
--[[ Resource: Runcode
     Script: shared.lua
     Author: ov-studio
     Developer(s): Aviril, Tron, Mario, Аниса, A-Variakojiene
     DOC: 23/07/2026
     Desc: Runtime code executor ]]--
----------------------------------------------------------------


-----------------------
--[[ Util: Runcode ]]--
-----------------------

local private = {
    command = "run"
}


-- Compiles and executes an arbitrary chunk of Lua code entered through the
-- console, printing either the returned results or the resulting error.
--
-- The code is compiled two ways so both expressions and statements are
-- supported from the console without the caller needing to type `return`:
--   1. As an expression, by prefixing it with `return`.
--   2. As a plain statement/chunk, verbatim.
-- If neither form compiles, the original compiler errors are reported.
function private.run(code)
    local prefix = "> "
    local try_expr = "return "..code
    local ok_expr, err_expr = core.engine.compile_string(try_expr, "runcode")
    local ok_code, err_code = core.engine.compile_string(code, "runcode")
    if not ok_expr and not ok_code then
        core.engine.print("error", "Failed run command\n"..prefix.."Code: `"..code.."`\n"..prefix.."Error: "..(err_code or err_expr))
        return
    end

    private.env = private.env or setmetatable({}, { __index = _G })
    local exec = (ok_expr and core.engine.load_string(try_expr, "runcode", false, true, private.env)) or core.engine.load_string(code, "runcode", false, true, private.env)
    if not exec then return end
    local results = util.table.pack(pcall(exec))
    local success = util.table.remove(results, 1)
    if not success then
        core.engine.print("error", "Failed run command\n"..prefix.."Code: `"..code.."`\n"..prefix.."Error: "..tostring(results[1]))
        return
    end

    local formatted_result = ""
    for i = 1, util.table.len(results) do
        local value = results[i]
        local value_type = type(value)
        local formatted_value = ((value_type == "string") and string.format("%q", value)) or tostring(value)
        formatted_value = formatted_value:gsub("^"..value_type..": ", "")
        formatted_result = formatted_result.."• `"..value_type.."`: "..formatted_value
        if i < util.table.len(results) then
            formatted_result = formatted_result.."\n"..prefix
        end
    end
    core.engine.print("info", "Executed run command\n"..prefix.."Code: `"..code.."`\n"..prefix.."Results ("..util.table.len(results).."):\n"..prefix..formatted_result)
end


----------------
--[[ Events ]]--
----------------

util.event.on("sandbox:console_input", function(command, args)
    if private.command ~= command then return false end
    local code = util.table.concat(args, " ")
    if util.string.void(code) then return core.engine.print("warn", "Usage: run <code>") end
    private.run(code)
end)
