(function () {
    const list = document.getElementById('recipe-list');
    const table = document.getElementById('recipe-table');
    const button = document.getElementById('back-button');
    if (!list || !table || !button) return;

    button.addEventListener('click', showList);

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
        list.style.display = '';
        button.style.display = 'none';
    }

    function renderRecipe(data) {
        table.innerHTML = '';
        data.rows.forEach(function (row) {
            const tr = document.createElement('tr');
            row.forEach(function (cell) {
                tr.appendChild(buildCell(cell));
            });
            table.appendChild(tr);
        });
        table.style.display = '';
        list.style.display = 'none';
        button.style.display = '';
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
                data.recipes.forEach(function (name) {
                    const li = document.createElement('li');
                    const a = document.createElement('a');
                    a.href = '#' + encodeURIComponent(name);
                    a.textContent = name;
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