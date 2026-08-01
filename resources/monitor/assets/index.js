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
