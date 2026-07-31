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

-- ─── HTML ─────────────────────────────────────────────────────────────────────
local MONITOR_HTML = [[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/ov-studio/Vital.site@main/app/theme.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/ov-studio/Vital.site@main/app/global.css">
<style>
  html, body {
    width: 100%; height: 100%;
    background: transparent !important;
    overflow: hidden;
    user-select: none;
  }

  * {
    cursor: auto;
  }

  .panel {
    position: fixed;
    width: 375px;
    background: var(--bg3);
    border: 1px solid var(--rule);
    cursor: default;
  }

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 36px;
    padding: 0 14px;
    background: var(--bg5);
    border-bottom: 1px solid var(--rule);
    cursor: grab;
  }
  .panel-header:active { cursor: grabbing; }

  .panel-header .title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-family: 'Geist', sans-serif;
    font-size: .7rem;
    font-weight: 700;
    letter-spacing: .08em;
    text-transform: uppercase;
    color: var(--blue);
  }
  .panel-header .title::before {
    content: '';
    width: 10px;
    height: 2px;
    background: var(--blue);
    flex-shrink: 0;
  }

  .panel-header .count {
    font-family: 'Geist', sans-serif;
    font-size: .68rem;
    font-weight: 500;
    letter-spacing: .04em;
    color: var(--text-faint);
  }

  .panel-rows {
    overflow-y: auto;
    overflow-x: hidden;
    max-height: 80vh;
    min-height: 50px;
  }

  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 26px;
    padding: 0 14px;
    background: var(--bg3);
    border-bottom: 1px solid var(--rule7);
    transition: background .15s;
  }
  .row:hover { background: var(--bg5); }

  .row .key {
    font-family: 'Geist', sans-serif;
    font-size: .68rem;
    font-weight: 500;
    letter-spacing: .05em;
    text-transform: uppercase;
    color: var(--dim);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .row .val {
    font-family: 'Geist', sans-serif;
    font-size: .68rem;
    font-weight: 600;
    letter-spacing: .04em;
    color: var(--blue);
    white-space: nowrap;
    margin-left: 8px;
    flex-shrink: 0;
  }

  .panel-resize {
    height: 4px;
    background: var(--b05);
    border-top: 1px solid var(--rule);
    cursor: ns-resize;
    transition: background .15s;
  }
  .panel-resize:hover { background: var(--b18); }
</style>
</head>
<body>

<div class="panel" id="panel-natives" style="top:8px; right:8px; left:auto;">
  <div class="panel-header" data-panel="panel-natives">
    <span class="title">NATIVES</span><span class="count" id="natives-count">#0</span>
  </div>
  <div class="panel-rows" id="natives-rows"></div>
  <div class="panel-resize" data-rows="natives-rows"></div>
</div>

<div class="panel" id="panel-entities" style="top:8px;">
  <div class="panel-header" data-panel="panel-entities">
    <span class="title">ENTITIES</span><span class="count" id="entities-count">#0</span>
  </div>
  <div class="panel-rows" id="entities-rows"></div>
  <div class="panel-resize" data-rows="entities-rows"></div>
</div>

<script>
window.addEventListener('load', function() {
  var pn = document.getElementById('panel-natives');
  var pe = document.getElementById('panel-entities');

  function toLeftBased(el) {
    var r = el.getBoundingClientRect();
    el.style.left  = r.left + 'px';
    el.style.right = 'auto';
    el.style.top   = r.top  + 'px';
  }

  toLeftBased(pn);

  var rn = pn.getBoundingClientRect();
  pe.style.top  = '8px';
  pe.style.left = (rn.left - pe.offsetWidth - 8) + 'px';
});

// ── Drag panels ───────────────────────────────────────────────────────────────
var drag = null;

document.querySelectorAll('.panel-header').forEach(function(header) {
  header.addEventListener('mousedown', function(e) {
    if (e.button !== 0) return;
    var el = document.getElementById(header.getAttribute('data-panel'));
    var rect = el.getBoundingClientRect();
    drag = { el: el, ox: e.clientX - rect.left, oy: e.clientY - rect.top };
    e.preventDefault();
  });
});

document.addEventListener('mousemove', function(e) {
  if (drag) {
    var x = Math.max(0, Math.min(window.innerWidth  - drag.el.offsetWidth,  e.clientX - drag.ox));
    var y = Math.max(0, Math.min(window.innerHeight - drag.el.offsetHeight, e.clientY - drag.oy));
    drag.el.style.left = x + 'px';
    drag.el.style.top  = y + 'px';
  }
  if (resize) {
    var newH = Math.max(50, e.clientY - resize.startY + resize.startH);
    resize.rowsEl.style.maxHeight = newH + 'px';
  }
});

document.addEventListener('mouseup', function() { drag = null; resize = null; });

// ── Resize rows height ────────────────────────────────────────────────────────
var resize = null;

document.querySelectorAll('.panel-resize').forEach(function(handle) {
  handle.addEventListener('mousedown', function(e) {
    if (e.button !== 0) return;
    var rowsEl = document.getElementById(handle.getAttribute('data-rows'));
    resize = { rowsEl: rowsEl, startY: e.clientY, startH: rowsEl.offsetHeight };
    e.preventDefault();
  });
});

// ── Data update ───────────────────────────────────────────────────────────────
function updateMonitor(nativesJson, entitiesJson) {
  renderPanel('natives',  JSON.parse(nativesJson));
  renderPanel('entities', JSON.parse(entitiesJson));
}

function renderPanel(id, items) {
  var countEl = document.getElementById(id + '-count');
  var rowsEl  = document.getElementById(id + '-rows');
  countEl.textContent = '#' + items.length;

  var existing = rowsEl.children;
  for (var i = 0; i < items.length; i++) {
    var row;
    if (i < existing.length) {
      row = existing[i];
    } else {
      row = document.createElement('div');
      row.className = 'row';
      row.innerHTML = '<span class="key"></span><span class="val"></span>';
      rowsEl.appendChild(row);
    }
    row.children[0].textContent = items[i].label;
    row.children[1].textContent = items[i].value;
  }
  while (rowsEl.children.length > items.length) {
    rowsEl.removeChild(rowsEl.lastChild);
  }
}
</script>
</body>
</html>]]

-- ─── Webview ──────────────────────────────────────────────────────────────────
local monitor_view = core.webview.create({ forward_input = true })
monitor_view:load_html(MONITOR_HTML)
monitor_view:set_visible(true)

local last_resolution = {0, 0}

util.event.on("sandbox:draw", function()
    local res = core.engine.get_resolution()

    if res[1] ~= last_resolution[1] or res[2] ~= last_resolution[2] then
        monitor_view:set_size({ res[1], res[2] })
        monitor_view:set_position({ 0, 0 })
        last_resolution = res
    end

    local lists         = util.monitor.list()
    local natives_json  = stats_to_json(lists.native or {})
    local entities_json = stats_to_json(lists.custom  or {})

    monitor_view:eval(util.string.format(
        "updateMonitor(%q, %q);",
        natives_json, entities_json
    ))
end)