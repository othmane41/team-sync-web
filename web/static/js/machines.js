const Machines = {
    async render(container) {
        App.clearProgressListeners();

        container.innerHTML = `
            <div class="card-header">
                <h2>Machines</h2>
                <button class="btn btn-primary" onclick="Machines.showForm()">Add Machine</button>
            </div>
            <div id="machines-list"></div>
            <div id="machine-modal"></div>
        `;

        await this.loadList();
    },

    async loadList() {
        const machines = await App.api('/api/machines');
        const el = document.getElementById('machines-list');
        if (!el) return;

        if (!machines.length) {
            el.innerHTML = `
                <div class="card empty-state">
                    <p>No machines configured</p>
                    <button class="btn btn-primary" onclick="Machines.showForm()">Add your first machine</button>
                </div>
            `;
            return;
        }

        el.innerHTML = `
            <div class="card">
                <table>
                    <thead><tr>
                        <th>Name</th><th>Connection</th><th>Port</th><th>Added</th><th>Actions</th>
                    </tr></thead>
                    <tbody>${machines.map(m => `
                        <tr>
                            <td><strong>${m.name}</strong></td>
                            <td style="font-family:monospace;font-size:13px">${m.user}@${m.host}</td>
                            <td>${m.port}</td>
                            <td>${App.formatDate(m.created_at)}</td>
                            <td>
                                <button class="btn btn-sm btn-outline" onclick="Machines.test(${m.id})" id="test-btn-${m.id}">Test SSH</button>
                                <button class="btn btn-sm btn-outline" onclick="Machines.showForm(${m.id})">Edit</button>
                                <button class="btn btn-sm btn-danger" onclick="Machines.remove(${m.id})">Delete</button>
                            </td>
                        </tr>
                    `).join('')}</tbody>
                </table>
            </div>
        `;
    },

    showForm(editId) {
        const modal = document.getElementById('machine-modal');
        if (!modal) return;

        const isEdit = !!editId;
        modal.innerHTML = `
            <div class="modal-overlay" onclick="Machines.closeForm(event)">
                <div class="modal" onclick="event.stopPropagation()">
                    <h3>${isEdit ? 'Edit' : 'Add'} Machine</h3>
                    <form id="machine-form">
                        <div class="form-group">
                            <label>Name</label>
                            <input type="text" id="mf-name" placeholder="My MacBook" required>
                        </div>
                        <div class="form-row">
                            <div class="form-group">
                                <label>User</label>
                                <input type="text" id="mf-user" placeholder="username" required>
                            </div>
                            <div class="form-group">
                                <label>Host</label>
                                <input type="text" id="mf-host" placeholder="192.168.1.100" required>
                            </div>
                        </div>
                        <div class="form-group">
                            <label>SSH Port</label>
                            <input type="number" id="mf-port" value="22">
                        </div>
                        <input type="hidden" id="mf-id" value="${editId || ''}">
                        <div class="modal-actions">
                            <button type="button" class="btn btn-outline" onclick="Machines.closeForm()">Cancel</button>
                            <button type="submit" class="btn btn-primary">${isEdit ? 'Save' : 'Add'}</button>
                        </div>
                    </form>
                </div>
            </div>
        `;

        if (isEdit) {
            this.fillForm(editId);
        }

        document.getElementById('machine-form').addEventListener('submit', (e) => this.saveForm(e));
    },

    async fillForm(id) {
        const m = await App.api(`/api/machines/${id}`);
        document.getElementById('mf-name').value = m.name;
        document.getElementById('mf-user').value = m.user;
        document.getElementById('mf-host').value = m.host;
        document.getElementById('mf-port').value = m.port;
    },

    closeForm(event) {
        if (event && event.target !== event.currentTarget) return;
        const modal = document.getElementById('machine-modal');
        if (modal) modal.innerHTML = '';
    },

    async saveForm(e) {
        e.preventDefault();
        const id = document.getElementById('mf-id').value;
        const body = {
            name: document.getElementById('mf-name').value,
            user: document.getElementById('mf-user').value,
            host: document.getElementById('mf-host').value,
            port: parseInt(document.getElementById('mf-port').value) || 22,
        };

        if (id) {
            await App.api(`/api/machines/${id}`, { method: 'PUT', body });
            App.toast('Machine updated');
        } else {
            await App.api('/api/machines', { method: 'POST', body });
            App.toast('Machine added');
        }

        this.closeForm();
        this.loadList();
    },

    async test(id) {
        const btn = document.getElementById(`test-btn-${id}`);
        if (btn) { btn.textContent = 'Testing...'; btn.disabled = true; }

        // Remove previous error panel
        const prev = document.getElementById(`ssh-error-${id}`);
        if (prev) prev.remove();

        const result = await App.api(`/api/machines/${id}/test`, { method: 'POST' });
        const machine = await App.api(`/api/machines/${id}`);

        if (btn) {
            btn.disabled = false;
            if (result.ok) {
                btn.innerHTML = `<span class="status-dot ok"></span>OK (${result.latency})`;
                setTimeout(() => { btn.textContent = 'Test SSH'; }, 5000);
            } else {
                btn.innerHTML = `<span class="status-dot error"></span>Failed`;
                // Show persistent error panel with details + fix instructions
                const row = btn.closest('tr');
                if (row) {
                    const errorRow = document.createElement('tr');
                    errorRow.id = `ssh-error-${id}`;
                    const hint = this.getSSHHint(result.message, machine);
                    errorRow.innerHTML = `<td colspan="5" style="padding:12px 16px;background:rgba(239,68,68,0.08);border-left:3px solid var(--danger)">
                        <div style="display:flex;justify-content:space-between;align-items:start">
                            <div>
                                <div style="font-size:13px;font-weight:600;color:var(--danger);margin-bottom:6px">SSH Connection Failed</div>
                                <pre style="font-size:12px;color:var(--text-muted);white-space:pre-wrap;word-break:break-all;margin:0 0 8px 0;font-family:'SF Mono',Monaco,monospace;background:var(--bg-input);padding:8px 10px;border-radius:6px">${this.escapeHtml(result.message)}</pre>
                                <div style="font-size:12px;color:var(--text);line-height:1.6">${hint}</div>
                            </div>
                            <button class="btn btn-sm btn-outline" onclick="document.getElementById('ssh-error-${id}').remove()" style="flex-shrink:0;margin-left:12px">Dismiss</button>
                        </div>
                    </td>`;
                    row.after(errorRow);
                }
            }
        }
    },

    getSSHHint(message, machine) {
        const connStr = `${machine.user}@${machine.host}`;
        const msg = (message || '').toLowerCase();

        if (msg.includes('permission denied') || msg.includes('publickey')) {
            return `<strong>Fix:</strong> Your SSH key is not authorized on this machine.<br>
                Run in Terminal:<br>
                <code style="background:var(--bg-input);padding:4px 8px;border-radius:4px;font-size:12px;display:inline-block;margin:4px 0">ssh-copy-id ${connStr}</code><br>
                <span style="color:var(--text-muted)">If that fails, ask the remote user to enable Remote Login:<br>
                System Settings → General → Sharing → Remote Login → ON</span>`;
        }
        if (msg.includes('connection refused')) {
            return `<strong>Fix:</strong> SSH is not enabled on the remote machine.<br>
                The remote user needs to:<br>
                <span style="color:var(--text-muted)">System Settings → General → Sharing → Remote Login → ON</span>`;
        }
        if (msg.includes('no route') || msg.includes('host is down') || msg.includes('timed out') || msg.includes('network is unreachable')) {
            return `<strong>Fix:</strong> Cannot reach ${machine.host}.<br>
                <span style="color:var(--text-muted)">Check that both machines are on the same network / VPN and the IP is correct.</span>`;
        }
        if (msg.includes('host key') || msg.includes('known_hosts')) {
            return `<strong>Fix:</strong> Host key mismatch. Run:<br>
                <code style="background:var(--bg-input);padding:4px 8px;border-radius:4px;font-size:12px;display:inline-block;margin:4px 0">ssh-keygen -R ${machine.host}</code><br>
                <span style="color:var(--text-muted)">Then retry the test.</span>`;
        }
        if (msg.includes('resolve') || msg.includes('could not resolve')) {
            return `<strong>Fix:</strong> Hostname "${machine.host}" cannot be resolved.<br>
                <span style="color:var(--text-muted)">Try using the IP address instead.</span>`;
        }
        return `<span style="color:var(--text-muted)">Check that SSH is enabled on the remote machine and your key is authorized.</span>`;
    },

    escapeHtml(str) {
        const div = document.createElement('div');
        div.textContent = str || '';
        return div.innerHTML;
    },

    async remove(id) {
        if (!confirm('Delete this machine?')) return;
        await App.api(`/api/machines/${id}`, { method: 'DELETE' });
        App.toast('Machine deleted');
        this.loadList();
    }
};
