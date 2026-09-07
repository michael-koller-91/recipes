(function () {
  const table = document.getElementById('recipe-table');
  if (!table) return;

  function buildCell(cell) {
    const el = document.createElement(cell.tag || 'td');
    if (cell.class) el.className = cell.class;
    if (cell.colspan) el.setAttribute('colspan', cell.colspan);
    if (cell.rowspan) el.setAttribute('rowspan', cell.rowspan);
    el.textContent = cell.text || '';
    return el;
  }

  fetch('sauce/baked_oats.json')
    .then(function (res) { return res.json(); })
    .then(function (data) {
      data.rows.forEach(function (row) {
        const tr = document.createElement('tr');
        row.forEach(function (cell) {
          tr.appendChild(buildCell(cell));
        });
        table.appendChild(tr);
      });
    })
    .catch(function (err) {
      console.error('Could not load recipe table:', err);
    });
})();