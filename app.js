class LumanodeController {
    constructor() {
        this.apiBase = '/api';
        this.statusPoll = null;
        this.init();
    }

    async init() {
        this.setupEventListeners();
        this.loadSketches();
        this.startStatusPolling();
    }

    setupEventListeners() {
        document.getElementById('refresh-btn').addEventListener('click', () => this.loadSketches());
        document.getElementById('history-btn').addEventListener('click', () => this.showHistory());
        
        const modal = document.getElementById('history-modal');
        const closeBtn = modal.querySelector('.close-btn');
        closeBtn.addEventListener('click', () => this.closeHistory());
        modal.addEventListener('click', (e) => {
            if (e.target === modal) this.closeHistory();
        });
    }

    async loadSketches() {
        try {
            const response = await fetch(`${this.apiBase}/sketches`);
            const data = await response.json();
            this.renderSketches(data.sketches, data.active_sketch);
        } catch (error) {
            console.error('Failed to load sketches:', error);
            this.setError('Failed to load sketches');
        }
    }

    renderSketches(sketches, activeSketch) {
        const container = document.getElementById('sketches-container');
        
        if (sketches.length === 0) {
            container.innerHTML = '<div class="loading">No sketches found in visualizations/</div>';
            return;
        }

        // Organize sketches by folder
        const byFolder = {};
        sketches.forEach(sketch => {
            const folder = sketch.folder || 'Root';
            if (!byFolder[folder]) byFolder[folder] = [];
            byFolder[folder].push(sketch);
        });

        container.innerHTML = '';

        // Render sketches grouped by folder
        Object.entries(byFolder).sort().forEach(([folder, folderSketches]) => {
            folderSketches.forEach(sketch => {
                const btn = document.createElement('button');
                btn.className = 'sketch-btn';
                if (sketch.is_active) btn.classList.add('active');
                
                const displayName = folder === 'Root' ? sketch.name : `${folder.split('/').pop()} / ${sketch.name}`;
                
                btn.innerHTML = `
                    <span class="sketch-name">${sketch.name}</span>
                    ${folder !== 'Root' ? `<span class="sketch-folder">${folder}</span>` : ''}
                    ${sketch.is_active ? '<span class="sketch-status">●</span>' : ''}
                `;
                
                btn.addEventListener('click', () => this.flashSketch(sketch.path));
                container.appendChild(btn);
            });
        });

        // Update active sketch display
        if (activeSketch) {
            document.getElementById('active-sketch').textContent = activeSketch;
        } else {
            document.getElementById('active-sketch').textContent = 'None';
        }
    }

    async flashSketch(sketchPath) {
        this.showStatusModal('Flashing...');
        
        try {
            const response = await fetch(`${this.apiBase}/flash/${encodeURIComponent(sketchPath)}`, {
                method: 'POST'
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            // Poll for completion
            await this.waitForCompletion();
            this.closeStatusModal();
            this.loadSketches();
        } catch (error) {
            console.error('Flash failed:', error);
            this.closeStatusModal();
            this.setError(`Flash failed: ${error.message}`);
        }
    }

    async waitForCompletion() {
        return new Promise((resolve) => {
            const check = async () => {
                try {
                    const response = await fetch(`${this.apiBase}/state`);
                    const state = await response.json();
                    
                    if (state.status === 'idle' || state.status === 'success' || state.status === 'error') {
                        resolve();
                    } else {
                        setTimeout(check, 500);
                    }
                } catch (error) {
                    setTimeout(check, 500);
                }
            };
            check();
        });
    }

    startStatusPolling() {
        this.statusPoll = setInterval(() => this.updateStatus(), 1000);
    }

    async updateStatus() {
        try {
            const response = await fetch(`${this.apiBase}/state`);
            const state = await response.json();
            
            const statusEl = document.getElementById('status');
            const msgEl = document.getElementById('status-message');
            
            statusEl.className = `status ${state.status}`;
            statusEl.textContent = state.status.toUpperCase();
            msgEl.textContent = state.message;

            if (state.status === 'error') {
                statusEl.classList.add('error');
            }
        } catch (error) {
            console.error('Status poll failed:', error);
        }
    }

    async showHistory() {
        try {
            const response = await fetch(`${this.apiBase}/history`);
            const data = await response.json();
            
            const historyList = document.getElementById('history-list');
            
            if (data.history.length === 0) {
                historyList.innerHTML = '<p style="text-align: center; color: var(--text-secondary);">No flash history</p>';
            } else {
                historyList.innerHTML = data.history.map(entry => {
                    const date = new Date(entry.timestamp);
                    const timeStr = date.toLocaleTimeString();
                    const dateStr = date.toLocaleDateString();
                    
                    return `
                        <div class="history-item ${entry.success ? 'success' : 'error'}">
                            <div class="sketch-name">${entry.sketch}</div>
                            <div class="timestamp">${dateStr} ${timeStr}</div>
                        </div>
                    `;
                }).join('');
            }
            
            document.getElementById('history-modal').classList.remove('hidden');
        } catch (error) {
            console.error('Failed to load history:', error);
            this.setError('Failed to load history');
        }
    }

    closeHistory() {
        document.getElementById('history-modal').classList.add('hidden');
    }

    showStatusModal(message) {
        const modal = document.getElementById('status-modal');
        document.getElementById('modal-message').textContent = message;
        modal.classList.remove('hidden');
    }

    closeStatusModal() {
        document.getElementById('status-modal').classList.add('hidden');
    }

    setError(message) {
        const statusEl = document.getElementById('status');
        const msgEl = document.getElementById('status-message');
        
        statusEl.className = 'status error';
        statusEl.textContent = 'ERROR';
        msgEl.textContent = message;
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    new LumanodeController();
});
