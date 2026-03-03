const Transfer = {
    async render(container) {
        App.clearProgressListeners();

        const machines = await App.api('/api/machines');

        container.innerHTML = `
            <h2>New Transfer</h2>
            <div class="card">
                <form id="transfer-form">
                    <div class="form-group">
                        <label>Machine</label>
                        <select id="tf-machine" required>
                            <option value="">Select a machine...</option>
                            ${machines.map(m => `<option value="${m.id}">${m.name} (${m.user}@${m.host})</option>`).join('')}
                        </select>
                    </div>
                    <input type="hidden" id="tf-direction" value="push">
                    <input type="hidden" id="tf-remote" value="/tmp">
                    <div class="form-group">
                        <label>File or folder to send</label>
                        <div class="drop-zone" id="drop-local"
                             ondragover="Transfer.dragOver(event, 'local')"
                             ondragleave="Transfer.dragLeave(event, 'local')"
                             ondrop="Transfer.drop(event, 'local')">
                            <div class="drop-zone-icon">📂</div>
                            <div class="drop-zone-text">
                                Drag a file or folder here<br>
                                <small>or</small>
                            </div>
                            <div class="drop-zone-actions">
                                <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.browse('local')">Browse...</button>
                                <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.toggleManual('local')">Type path</button>
                            </div>
                        </div>
                        <input type="text" id="tf-local" placeholder="/Users/you/project/" required style="display:none">
                        <p style="margin-top:8px;font-size:12px;color:var(--text-muted)">Destination: <code style="background:var(--bg-input);padding:2px 6px;border-radius:4px">/tmp</code> on remote machine</p>
                    </div>
                    <button type="submit" class="btn btn-primary" id="tf-submit">Start Transfer</button>
                </form>
            </div>
            <div id="browser-modal"></div>
            ${!machines.length ? '<p style="color:var(--text-muted);margin-top:12px">No machines configured. <a href="#/machines" style="color:var(--accent)">Add one first</a>.</p>' : ''}
        `;

        document.getElementById('transfer-form').addEventListener('submit', (e) => this.submit(e));
    },

    // --- Drag & Drop (local only) ---
    dragOver(e, field) {
        e.preventDefault();
        e.stopPropagation();
        document.getElementById(`drop-${field}`).classList.add('dragover');
    },

    dragLeave(e, field) {
        e.preventDefault();
        e.stopPropagation();
        document.getElementById(`drop-${field}`).classList.remove('dragover');
    },

    drop(e, field) {
        e.preventDefault();
        e.stopPropagation();
        const zone = document.getElementById(`drop-${field}`);
        zone.classList.remove('dragover');

        // Try text data first (path dragged from terminal / another app)
        const text = e.dataTransfer.getData('text/plain');
        if (text && text.trim()) {
            this.setPath(field, text.trim());
            return;
        }

        // File drop — can only get name, open browser to help locate
        const items = e.dataTransfer.items;
        if (items && items.length > 0) {
            const entry = items[0].webkitGetAsEntry && items[0].webkitGetAsEntry();
            const name = entry ? entry.name : (items[0].getAsFile() ? items[0].getAsFile().name : null);
            if (name) {
                App.toast(`Dropped: ${name} — use Browse to select the full path`, 'success');
                this.browse(field);
            }
        }
    },

    setPath(field, path) {
        const input = document.getElementById(`tf-${field}`);
        input.value = path;
        input.style.display = 'none';

        const zone = document.getElementById(`drop-${field}`);
        zone.classList.add('has-value');
        zone.style.display = 'block';
        zone.innerHTML = `
            <div class="drop-zone-path">${path}</div>
            <div class="drop-zone-actions">
                <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.browse('${field}')">Change</button>
                <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.clearPath('${field}')">Clear</button>
            </div>
        `;
    },

    clearPath(field) {
        const input = document.getElementById(`tf-${field}`);
        input.value = '';

        const zone = document.getElementById(`drop-${field}`);
        zone.classList.remove('has-value');
        if (field === 'local') {
            zone.innerHTML = `
                <div class="drop-zone-icon">📂</div>
                <div class="drop-zone-text">Drag a file or folder here<br><small>or</small></div>
                <div class="drop-zone-actions">
                    <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.browse('local')">Browse...</button>
                    <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.toggleManual('local')">Type path</button>
                </div>
            `;
        } else {
            zone.innerHTML = `
                <div class="drop-zone-icon">🌐</div>
                <div class="drop-zone-text">Browse the remote machine<br><small>select a machine first</small></div>
                <div class="drop-zone-actions">
                    <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.browse('remote')">Browse remote...</button>
                    <button type="button" class="btn btn-sm btn-outline" onclick="Transfer.toggleManual('remote')">Type path</button>
                </div>
            `;
        }
    },

    toggleManual(field) {
        const input = document.getElementById(`tf-${field}`);
        const zone = document.getElementById(`drop-${field}`);
        if (input.style.display === 'none') {
            input.style.display = 'block';
            zone.style.display = 'none';
            input.focus();
            input.onblur = () => {
                if (input.value.trim()) {
                    this.setPath(field, input.value.trim());
                    zone.style.display = 'block';
                }
            };
        } else {
            input.style.display = 'none';
            zone.style.display = 'block';
        }
    },

    // --- File Browser ---
    browserField: null,
    browserSelected: null,
    browserLoading: false,

    async browse(field) {
        this.browserField = field;
        this.browserSelected = null;

        if (field === 'remote') {
            const machineId = document.getElementById('tf-machine').value;
            if (!machineId) {
                App.toast('Select a machine first', 'error');
                return;
            }
        }

        const currentValue = document.getElementById(`tf-${field}`).value;
        await this.loadBrowser(currentValue || '');
    },

    async loadBrowser(path) {
        const modal = document.getElementById('browser-modal');
        const field = this.browserField;
        const isRemote = field === 'remote';

        // Show loading state
        if (!modal.innerHTML) {
            modal.innerHTML = `
                <div class="modal-overlay">
                    <div class="modal modal-lg">
                        <h3>${isRemote ? '🌐 Remote' : '📂 Local'} file browser</h3>
                        <div style="text-align:center;padding:40px;color:var(--text-muted)">
                            <div class="spinner"></div>
                            ${isRemote ? 'Connecting via SSH...' : 'Loading...'}
                        </div>
                    </div>
                </div>
            `;
        }

        let data;
        if (isRemote) {
            const machineId = document.getElementById('tf-machine').value;
            data = await App.api(`/api/machines/${machineId}/browse?path=${encodeURIComponent(path)}`);
        } else {
            data = await App.api(`/api/browse?path=${encodeURIComponent(path)}`);
        }

        if (data.error) {
            App.toast(data.error, 'error');
            this.closeBrowser();
            return;
        }

        const pathParts = data.current.split('/').filter(Boolean);
        const title = isRemote ? '🌐 Remote file browser' : '📂 Local file browser';
        const escapePath = (p) => p.replace(/'/g, "\\'").replace(/\\/g, "\\\\");

        modal.innerHTML = `
            <div class="modal-overlay" onclick="Transfer.closeBrowser(event)">
                <div class="modal modal-lg" onclick="event.stopPropagation()">
                    <h3>${title}</h3>
                    <div class="file-browser-path">
                        <button onclick="Transfer.loadBrowser('/')">/</button>
                        ${pathParts.map((part, i) => {
                            const fullPath = '/' + pathParts.slice(0, i + 1).join('/');
                            return `<span>/</span><button onclick="Transfer.loadBrowser('${escapePath(fullPath)}')">${part}</button>`;
                        }).join('')}
                    </div>
                    <div class="file-browser" id="browser-list">
                        <ul class="file-list">
                            ${data.current !== '/' ? `
                                <li class="file-item" ondblclick="Transfer.loadBrowser('${escapePath(data.parent)}')">
                                    <span class="file-item-icon">⬆️</span>
                                    <span class="file-item-name">..</span>
                                    <span class="file-item-size"></span>
                                </li>
                            ` : ''}
                            ${(data.entries || []).map(f => `
                                <li class="file-item"
                                    onclick="Transfer.selectItem(this, '${escapePath(f.path)}')"
                                    ondblclick="${f.is_dir ? `Transfer.loadBrowser('${escapePath(f.path)}')` : ''}">
                                    <span class="file-item-icon">${f.is_dir ? '📁' : '📄'}</span>
                                    <span class="file-item-name">${f.name}</span>
                                    <span class="file-item-size">${f.is_dir ? '' : (f.size ? App.formatBytes(f.size) : '')}</span>
                                </li>
                            `).join('')}
                            ${!(data.entries || []).length ? '<li style="padding:20px;text-align:center;color:var(--text-muted)">Empty directory</li>' : ''}
                        </ul>
                    </div>
                    <div style="margin-top:12px;display:flex;align-items:center;gap:8px">
                        <span style="font-size:12px;color:var(--text-muted);white-space:nowrap">Selected:</span>
                        <input type="text" id="browser-selected-path" value="${data.current}"
                               style="flex:1;padding:8px 10px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius);color:var(--text);font-family:monospace;font-size:13px">
                    </div>
                    <div class="modal-actions">
                        <button type="button" class="btn btn-outline" onclick="Transfer.closeBrowser()">Cancel</button>
                        <button type="button" class="btn btn-primary" onclick="Transfer.confirmBrowser()">Select</button>
                    </div>
                </div>
            </div>
        `;
    },

    selectItem(el, path) {
        document.querySelectorAll('#browser-list .file-item.selected').forEach(e => e.classList.remove('selected'));
        el.classList.add('selected');
        this.browserSelected = path;
        const pathInput = document.getElementById('browser-selected-path');
        if (pathInput) pathInput.value = path;
    },

    closeBrowser(event) {
        if (event && event.target !== event.currentTarget) return;
        document.getElementById('browser-modal').innerHTML = '';
    },

    confirmBrowser() {
        const pathInput = document.getElementById('browser-selected-path');
        const path = pathInput ? pathInput.value : this.browserSelected;
        if (path) {
            this.setPath(this.browserField, path);
        }
        this.closeBrowser();
    },

    // --- Submit ---
    async submit(e) {
        e.preventDefault();
        const btn = document.getElementById('tf-submit');
        btn.disabled = true;
        btn.textContent = 'Starting...';

        const body = {
            machine_id: parseInt(document.getElementById('tf-machine').value),
            direction: document.getElementById('tf-direction').value,
            local_path: document.getElementById('tf-local').value,
            remote_path: document.getElementById('tf-remote').value,
        };

        if (!body.local_path) {
            App.toast('Please select a file or folder to send', 'error');
            btn.disabled = false;
            btn.textContent = 'Start Transfer';
            return;
        }

        const result = await App.api('/api/transfers', { method: 'POST', body });

        if (result.error) {
            App.toast(result.error, 'error');
            btn.disabled = false;
            btn.textContent = 'Start Transfer';
            return;
        }

        App.toast('Transfer started');
        location.hash = '#/';
    }
};
