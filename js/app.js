(function () {
    const list = document.getElementById('recipe-list');
    const table = document.getElementById('recipe-table');
    const button = document.getElementById('back-button');
    const factorInput = document.getElementById('factor');
    const factorRow = document.getElementById('factor-row');
    if (!list || !table || !button || !factorInput || !factorRow) return;

    let baseRows = [];

    function multiply(text, factor) {
        return text.replace(/(\d+(?:[.,]\d+)?)/g, function (m) {
            const num = parseFloat(m.replace(',', '.'));
            if (isNaN(num)) return m;
            const scaled = Math.round(num * factor * 100) / 100;
            return scaled % 1 === 0 ? String(Math.round(scaled)) : String(scaled);
        });
    }

    function renderRecipe(data) {
        baseRows = data.rows;
        factorInput.value = 1;
        factorRow.style.display = '';
        table.style.display = '';
        list.style.display = 'none';
        button.style.display = '';
        applyFactor();
    }

    function applyFactor() {
        const factor = parseFloat(factorInput.value) || 1;
        table.innerHTML = '';
        baseRows.forEach(function (row) {
            const tr = document.createElement('tr');
            row.forEach(function (cell) {
                const el = buildCell(cell);
                if (cell.scale) {
                    el.textContent = multiply(cell.text || '', factor);
                }
                tr.appendChild(el);
            });
            table.appendChild(tr);
        });
    }

    button.addEventListener('click', showList);
    factorInput.addEventListener('input', applyFactor);

    function buildCell(cell) {
        const el = document.createElement(cell.tag || 'td');
        if (cell.class) el.className = cell.class;
        if (cell.colspan) el.setAttribute('colspan', cell.colspan);
        if (cell.rowspan) el.setAttribute('rowspan', cell.rowspan);
        el.textContent = cell.text || '';
        return el;
    }

    function showList() {
        table.style.display = 'none';
        factorRow.style.display = 'none';
        list.style.display = '';
        button.style.display = 'none';
    }

    function showRecipe(name) {
        fetch('sauce/' + name + '.json')
            .then(function (res) { return res.json(); })
            .then(renderRecipe)
            .catch(function (err) {
                console.error('Could not load recipe:', err);
            });
    }

    function loadList() {
        fetch('sauce/index.json')
            .then(function (res) { return res.json(); })
            .then(function (data) {
                data.recipes.forEach(function (entry) {
                    const name = typeof entry === 'string' ? entry : entry.name;
                    const title = typeof entry === 'string' ? entry : entry.title;
                    const li = document.createElement('li');
                    const a = document.createElement('a');
                    a.href = '#' + encodeURIComponent(name);
                    a.textContent = title;
                    a.addEventListener('click', function (e) {
                        e.preventDefault();
                        showRecipe(name);
                    });
                    li.appendChild(a);
                    list.appendChild(li);
                });
            })
            .catch(function (err) {
                console.error('Could not load recipe list:', err);
            });
    }

    loadList();
})();