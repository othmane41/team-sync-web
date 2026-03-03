// SPA Router & WebSocket client
const App = {
    ws: null,
    progressListeners: [],

    init() {
        this.connectWebSocket();
        window.addEventListener('hashchange', () => this.route());
        this.route();
    },

    route() {
        const hash = location.hash || '#/';
        const page = hash.replace('#/', '') || 'dashboard';

        // Update nav
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.toggle('active', link.dataset.page === (page || 'dashboard'));
        });

        const app = document.getElementById('app');
        switch (page) {
            case 'dashboard':
            case '':
                Dashboard.render(app);
                break;
            case 'transfer':
                Transfer.render(app);
                break;
            case 'machines':
                Machines.render(app);
                break;
            case 'history':
                History.render(app);
                break;
            default:
                app.innerHTML = '<h2>Page not found</h2>';
        }
    },

    connectWebSocket() {
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        this.ws = new WebSocket(`${proto}//${location.host}/ws`);

        this.ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            this.progressListeners.forEach(fn => fn(msg));
        };

        this.ws.onclose = () => {
            setTimeout(() => this.connectWebSocket(), 2000);
        };
    },

    onProgress(fn) {
        this.progressListeners.push(fn);
        return () => {
            this.progressListeners = this.progressListeners.filter(f => f !== fn);
        };
    },

    clearProgressListeners() {
        this.progressListeners = [];
    },

    // API helpers
    async api(path, opts = {}) {
        const res = await fetch(path, {
            headers: { 'Content-Type': 'application/json' },
            ...opts,
            body: opts.body ? JSON.stringify(opts.body) : undefined,
        });
        return res.json();
    },

    toast(message, type = 'success') {
        const el = document.createElement('div');
        el.className = `toast toast-${type}`;
        el.textContent = message;
        document.body.appendChild(el);
        setTimeout(() => el.remove(), 3000);
    },

    formatBytes(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return (bytes / Math.pow(k, i)).toFixed(1) + ' ' + sizes[i];
    },

    formatDate(dateStr) {
        if (!dateStr) return '-';
        const d = new Date(dateStr);
        return d.toLocaleString();
    },

    statusBadge(status) {
        return `<span class="badge badge-${status}">${status}</span>`;
    },

    directionLabel(dir) {
        return `<span class="direction-push">PUSH ↑</span>`;
    }
};

document.addEventListener('DOMContentLoaded', () => App.init());
