const Dashboard = {
    cleanup: null,

    async render(container) {
        App.clearProgressListeners();

        container.innerHTML = `
            <h2>Dashboard</h2>
            <div id="active-transfers"></div>
            <div class="card" style="margin-top: 24px">
                <div class="card-header">
                    <h3 style="font-size:16px">Recent Transfers</h3>
                    <a href="#/history" class="btn btn-sm btn-outline">View all</a>
                </div>
                <div id="recent-transfers"></div>
            </div>
        `;

        await this.loadActive();
        await this.loadRecent();

        App.onProgress((msg) => {
            if (msg.type === 'progress') {
                this.updateProgress(msg.data);
            } else if (msg.type === 'status') {
                this.loadActive();
                this.loadRecent();
            }
        });
    },

    async loadActive() {
        const transfers = await App.api('/api/transfers?status=running');
        const el = document.getElementById('active-transfers');
        if (!el) return;

        if (!transfers.length) {
            el.innerHTML = `
                <div class="card empty-state">
                    <p>No active transfers</p>
                    <a href="#/transfer" class="btn btn-primary">Start a Transfer</a>
                </div>
            `;
            return;
        }

        el.innerHTML = transfers.map(t => `
            <div class="card" id="transfer-${t.id}">
                <div class="transfer-card">
                    <div class="transfer-info">
                        <h4>${App.directionLabel(t.direction)} ${t.machine_name || 'Unknown'}</h4>
                        <div class="path">${t.direction === 'push' ? t.local_path + ' → ' + t.remote_path : t.remote_path + ' → ' + t.local_path}</div>
                    </div>
                    <div class="transfer-progress">
                        <div style="font-size:14px;font-weight:500" id="pct-${t.id}">${this.calcPercent(t)}%</div>
                        <div class="progress-bar"><div class="progress-bar-fill" id="bar-${t.id}" style="width:${this.calcPercent(t)}%"></div></div>
                        <div class="progress-text" id="speed-${t.id}">${t.speed || '-'}</div>
                    </div>
                    <button class="btn btn-sm btn-danger" style="margin-left:16px" onclick="Dashboard.cancel(${t.id})">Cancel</button>
                </div>
            </div>
        `).join('');
    },

    async loadRecent() {
        const transfers = await App.api('/api/transfers?limit=10');
        const el = document.getElementById('recent-transfers');
        if (!el) return;

        if (!transfers.length) {
            el.innerHTML = '<div class="empty-state"><p>No transfers yet</p></div>';
            return;
        }

        el.innerHTML = `
            <table>
                <thead><tr>
                    <th>Direction</th><th>Machine</th><th>Path</th><th>Status</th><th>Size</th><th>Date</th>
                </tr></thead>
                <tbody>${transfers.map(t => `
                    <tr>
                        <td>${App.directionLabel(t.direction)}</td>
                        <td>${t.machine_name || '-'}</td>
                        <td class="path" style="font-size:12px">${t.direction === 'push' ? t.local_path : t.remote_path}</td>
                        <td>${App.statusBadge(t.status)}</td>
                        <td>${t.bytes_done > 0 ? App.formatBytes(t.bytes_done) : '-'}</td>
                        <td>${App.formatDate(t.created_at)}</td>
                    </tr>
                `).join('')}</tbody>
            </table>
        `;
    },

    updateProgress(data) {
        const pct = document.getElementById(`pct-${data.transfer_id}`);
        const bar = document.getElementById(`bar-${data.transfer_id}`);
        const speed = document.getElementById(`speed-${data.transfer_id}`);
        if (pct) pct.textContent = data.percent + '%';
        if (bar) bar.style.width = data.percent + '%';
        if (speed) speed.textContent = data.speed + (data.eta ? ' | ETA: ' + data.eta : '');
    },

    calcPercent(t) {
        if (t.bytes_total > 0) return Math.round(t.bytes_done / t.bytes_total * 100);
        return 0;
    },

    async cancel(id) {
        await App.api(`/api/transfers/${id}/cancel`, { method: 'POST' });
        App.toast('Transfer cancelled');
        this.loadActive();
    }
};
