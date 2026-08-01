window.addEventListener('load', function() {
  var pn = document.getElementById('panel-natives');
  var pe = document.getElementById('panel-entities');

  // Natives: top-right, vw/vh based
  pn.style.top   = '1vh';
  pn.style.right = '1vw';
  pn.style.left  = 'auto';

  // Entities: to the left of natives, gap = 1vw
  var rn = pn.getBoundingClientRect();
  pe.style.top  = '1vh';
  pe.style.left = (rn.left - pe.offsetWidth - window.innerWidth * 0.01) + 'px';
});

// Reposition on window resize
window.addEventListener('resize', function() {
  var pn = document.getElementById('panel-natives');
  var pe = document.getElementById('panel-entities');
  pn.style.top   = '1vh';
  pn.style.right = '1vw';
  pn.style.left  = 'auto';
  var rn = pn.getBoundingClientRect();
  pe.style.top  = '1vh';
  pe.style.left = (rn.left - pe.offsetWidth - window.innerWidth * 0.01) + 'px';
});

// ── Z-index stacking (bring-to-front) ────────────────────────────────────────
var topZ = 2; // panel-entities starts as the front-most panel

function bringToFront(panelId) {
  var el = document.getElementById(panelId);
  topZ += 1;
  el.style.zIndex = topZ;
}

// ── Drag panels ───────────────────────────────────────────────────────────────
var drag = null;

document.querySelectorAll('.panel-header').forEach(function(header) {
  header.addEventListener('mousedown', function(e) {
    if (e.button !== 0) return;
    var panelId = header.getAttribute('data-panel');
    bringToFront(panelId);
    var el = document.getElementById(panelId);
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
    var panelEl = rowsEl.closest('.panel');
    if (panelEl) bringToFront(panelEl.id);
    resize = { rowsEl: rowsEl, startY: e.clientY, startH: rowsEl.offsetHeight };
    e.preventDefault();
  });
});

// ── Sparkline graphs (FPS + memory) ─────────────────────────────────────────
var HISTORY_MAX = 120;
var graphs = {
  fps: { canvasId: 'fps-canvas', history: [], minFloor: 30 },
  mem: { canvasId: 'mem-canvas', history: [], minFloor: 1 }
};

function getThemeColor(varName, fallback) {
  var v = getComputedStyle(document.documentElement).getPropertyValue(varName).trim();
  if (!v) v = getComputedStyle(document.body).getPropertyValue(varName).trim();
  return v || fallback;
}

function drawSparkline(graph) {
  var canvas = document.getElementById(graph.canvasId);
  var history = graph.history;
  if (!canvas || history.length === 0) return;

  var dpr = window.devicePixelRatio || 1;
  var cw = canvas.clientWidth;
  var ch = canvas.clientHeight;
  if (cw === 0 || ch === 0) return;

  if (canvas.width !== Math.round(cw * dpr) || canvas.height !== Math.round(ch * dpr)) {
    canvas.width  = Math.round(cw * dpr);
    canvas.height = Math.round(ch * dpr);
  }

  var ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, cw, ch);

  var maxVal = Math.max.apply(null, history);
  maxVal = Math.max(maxVal * 1.15, graph.minFloor);

  var n = history.length;
  // Stretch whatever samples we have across the full canvas width, so the
  // graph is visible immediately rather than waiting for HISTORY_MAX
  // samples to accumulate.
  var stepX = cw / Math.max(n - 1, 1);
  var pad = 5;

  var points = [];
  for (var i = 0; i < n; i++) {
    var x = i * stepX;
    var y = pad + (ch - pad * 2) - (history[i] / maxVal) * (ch - pad * 2);
    points.push([x, y]);
  }
  if (points.length === 1) {
    points.push([cw, points[0][1]]);
  }

  var blue = getThemeColor('--blue', '#3b82f6');

  var gradient = ctx.createLinearGradient(0, 0, 0, ch);
  gradient.addColorStop(0, blue);
  gradient.addColorStop(1, 'transparent');

  // Smooth the line using quadratic curves through midpoints, rather than
  // sharp straight segments, so it reads as a clean line at a small height.
  function tracePath(ctx2) {
    ctx2.moveTo(points[0][0], points[0][1]);
    for (var m = 1; m < points.length - 1; m++) {
      var mx = (points[m][0] + points[m + 1][0]) / 2;
      var my = (points[m][1] + points[m + 1][1]) / 2;
      ctx2.quadraticCurveTo(points[m][0], points[m][1], mx, my);
    }
    if (points.length > 1) {
      var last = points[points.length - 1];
      ctx2.lineTo(last[0], last[1]);
    }
  }

  ctx.beginPath();
  ctx.moveTo(points[0][0], ch);
  ctx.lineTo(points[0][0], points[0][1]);
  tracePath(ctx);
  ctx.lineTo(points[points.length - 1][0], ch);
  ctx.closePath();
  ctx.save();
  ctx.globalAlpha = 0.4;
  ctx.fillStyle = gradient;
  ctx.fill();
  ctx.restore();

  ctx.beginPath();
  tracePath(ctx);
  ctx.strokeStyle = blue;
  ctx.lineWidth = 1.25;
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.stroke();
}

function pushHistory(graph, value) {
  graph.history.push(value);
  if (graph.history.length > HISTORY_MAX) graph.history.shift();
}

function findItem(items, label) {
  return items.filter(function(i) { return i.label === label; })[0];
}

function formatNumber(n) {
  return Math.round(n).toLocaleString();
}

function updateGraphs(natives) {
  // FPS graph: big number = current FPS, sub-label = frame time
  var fpsItem = findItem(natives, 'TIME FPS');
  var msItem  = findItem(natives, 'TIME PROCESS');
  var fpsVal = fpsItem ? parseFloat(fpsItem.value) : 0;
  if (isNaN(fpsVal)) fpsVal = 0;
  pushHistory(graphs.fps, fpsVal);

  var fpsValEl = document.getElementById('fps-value');
  if (fpsValEl) {
    var fpsMs = msItem ? msItem.value.replace(' MS', 'ms').toLowerCase() : '';
    fpsValEl.innerHTML = Math.round(fpsVal) + (fpsMs ? ' <span class="val-sub">(' + fpsMs + ')</span>' : '');
  }

  drawSparkline(graphs.fps);

  // Memory graph: big number = current static memory, sub-label = usage vs max
  // Note: the engine's MEMORY STATIC / MEMORY STATIC MAX values are raw bytes
  // even though the source data appends " MB" to them, so we convert here to
  // show real usage instead of a mislabeled billion-scale number.
  var memItem    = findItem(natives, 'MEMORY STATIC');
  var memMaxItem = findItem(natives, 'MEMORY STATIC MAX');
  var memValBytes = memItem ? parseFloat(memItem.value) : 0;
  if (isNaN(memValBytes)) memValBytes = 0;
  var memMb = memValBytes / (1024 * 1024);
  pushHistory(graphs.mem, memMb);

  var memValEl = document.getElementById('mem-value');
  if (memValEl) {
    var memText = memMb.toFixed(1) + ' MB';
    if (memMaxItem) {
      var memMaxMb = parseFloat(memMaxItem.value) / (1024 * 1024);
      if (memMaxMb > 0) {
        var memPct = Math.round((memMb / memMaxMb) * 100);
        memText += ' <span class="val-sub">(' + memPct + '%)</span>';
      }
    }
    memValEl.innerHTML = memText;
  }

  drawSparkline(graphs.mem);
}

window.addEventListener('resize', function() {
  drawSparkline(graphs.fps);
  drawSparkline(graphs.mem);
});

// ── Data update ───────────────────────────────────────────────────────────────
function updateMonitor(nativesJson, entitiesJson) {
  var natives  = JSON.parse(nativesJson);
  var entities = JSON.parse(entitiesJson);
  renderPanel('natives',  natives);
  renderPanel('entities', entities);
  updateGraphs(natives);
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
