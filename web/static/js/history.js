const History = {
    page: 0,
    pageSize: 20,
    filter: '',

    async render(container) {
        App.clearProgressListeners();
        this.page = 0;
        this.filter = '';

        container.innerHTML = `
            <h2>Transfer History</h2>
            <div class="card">
                <div class="card-header">
                    <div style="display:flex;gap:8px">
                        <select id="hist-filter" style="padding:6px 10px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius);color:var(--text);font-size:13px">
                            <option value="">All statuses</option>
                            <option value="completed">Completed</option>
                            <option value="failed">Failed</option>
                            <option value="cancelled">Cancelled</option>
                            <option value="running">Running</option>
                        </select>
                    </div>
                </div>
                <div id="history-table"></div>
                <div id="history-pagination" class="pagination"></div>
            </div>
        `;

        document.getElementById('hist-filter').addEventListener('change', (e) => {
            this.filter = e.target.value;
            this.page = 0;
            this.load();
        });

        await this.load();
    },

    async load() {
        let url = `/api/transfers?limit=${this.pageSize + 1}`;
        if (this.filter) url += `&status=${this.filter}`;

        const transfers = await App.api(url);
        const hasMore = transfers.length > this.pageSize;
        const items = transfers.slice(0, this.pageSize);

        const el = document.getElementById('history-table');
        if (!el) return;

        if (!items.length) {
            el.innerHTML = '<div class="empty-state"><p>No transfers found</p></div>';
            document.getElementById('history-pagination').innerHTML = '';
            return;
        }

        el.innerHTML = `
            <table>
                <thead><tr>
                    <th>ID</th><th>Direction</th><th>Machine</th><th>Local Path</th><th>Remote Path</th>
                    <th>Status</th><th>Size</th><th>Speed</th><th>Date</th>
                </tr></thead>
                <tbody>${items.map(t => `
                    <tr>
                        <td>#${t.id}</td>
                        <td>${App.directionLabel(t.direction)}</td>
                        <td>${t.machine_name || '-'}</td>
                        <td style="font-family:monospace;font-size:12px;max-width:180px;overflow:hidden;text-overflow:ellipsis">${t.local_path}</td>
                        <td style="font-family:monospace;font-size:12px;max-width:180px;overflow:hidden;text-overflow:ellipsis">${t.remote_path}</td>
                        <td>${App.statusBadge(t.status)}</td>
                        <td>${t.bytes_done > 0 ? App.formatBytes(t.bytes_done) : '-'}</td>
                        <td>${t.speed || '-'}</td>
                        <td style="white-space:nowrap">${App.formatDate(t.created_at)}</td>
                    </tr>
                    ${t.error_message ? `<tr><td colspan="9" style="color:var(--danger);font-size:12px;padding-top:0">${t.error_message}</td></tr>` : ''}
                `).join('')}</tbody>
            </table>
        `;

        const pag = document.getElementById('history-pagination');
        pag.innerHTML = `
            ${this.page > 0 ? '<button class="btn btn-sm btn-outline" onclick="History.prev()">Previous</button>' : ''}
            ${hasMore ? '<button class="btn btn-sm btn-outline" onclick="History.next()">Next</button>' : ''}
        `;
    },

    next() { this.page++; this.load(); },
    prev() { if (this.page > 0) { this.page--; this.load(); } }
};
