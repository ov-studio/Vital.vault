-- ─── Register entity-count stats ─────────────────────────────────────────────
for _, kind in ipairs(core.engine.get_entity_types()) do
    util.monitor.register(
        kind .. "_entity_count",
        util.string.upper(kind) .. "_ENTITY_COUNT",
        function() return #core.engine.get_entities(kind) end,
        util.monitor.stat_format.QUANTITY
    )
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function get_unit(fmt)
    if fmt == util.monitor.stat_format.TIME       then return " MS"
    elseif fmt == util.monitor.stat_format.MEMORY then return " MB"
    elseif fmt == util.monitor.stat_format.PERCENTAGE then return " %"
    end
    return ""
end

local function stats_to_json(list)
    local parts = {}
    for _, item in ipairs(list) do
        local value = util.math.round(util.monitor.get(item.id), 2)
        local label = util.string.gsub(item.name, "_", " ")
        local unit  = get_unit(item.format)
        parts[#parts + 1] = util.string.format(
            '{"label":"%s","value":"%s%s"}',
            label, tostring(value), unit
        )
    end
    return "[" .. util.table.concat(parts, ",") .. "]"
end

-- ─── Webview ──────────────────────────────────────────────────────────────────
local monitor_view = core.webview.create({ forward_input = true })
monitor_view:load_url("assets/widget/index.html")
monitor_view:set_visible(true)

util.event.on("sandbox:draw", function()
    local res = core.engine.get_resolution()
    local lists = util.monitor.list()
    local natives_json  = stats_to_json(lists.native or {})
    local entities_json = stats_to_json(lists.custom  or {})

    monitor_view:eval(util.string.format(
        "updateMonitor(%q, %q);",
        natives_json, entities_json
    ))
end)
