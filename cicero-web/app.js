// Cicero Web App - Main JavaScript
class CiceroApp {
    constructor() {
        this.apiBaseUrl = this.getApiBaseUrl();
        this.messages = this.loadMessages();
        this.selectedState = this.loadState() || 'CA';
        this.isLoading = false;
        this.currentUser = null;
        this.authToken = null;
        
        this.initAuth();
    }

    async initAuth() {
        firebase.auth().onAuthStateChanged(async (user) => {
            if (user) {
                this.currentUser = user;
                this.authToken = await user.getIdToken();
                document.getElementById('appContainer').style.display = 'block';
                document.getElementById('loginModal').style.display = 'none';
                this.init();
            } else {
                document.getElementById('appContainer').style.display = 'none';
                document.getElementById('loginModal').style.display = 'block';
                this.setupAuthListeners();
            }
        });
    }

    setupAuthListeners() {
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('loginEmail').value;
            const password = document.getElementById('loginPassword').value;
            try {
                await firebase.auth().signInWithEmailAndPassword(email, password);
            } catch (error) {
                document.getElementById('authError').textContent = error.message;
                document.getElementById('authError').style.display = 'block';
            }
        });

        document.getElementById('registerForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const email = document.getElementById('registerEmail').value;
            const password = document.getElementById('registerPassword').value;
            const confirm = document.getElementById('confirmPassword').value;
            if (password !== confirm) {
                document.getElementById('authError').textContent = 'Passwords do not match';
                document.getElementById('authError').style.display = 'block';
                return;
            }
            try {
                await firebase.auth().createUserWithEmailAndPassword(email, password);
            } catch (error) {
                document.getElementById('authError').textContent = error.message;
                document.getElementById('authError').style.display = 'block';
            }
        });

        document.getElementById('switchToRegister').addEventListener('click', () => {
            document.getElementById('loginForm').style.display = 'none';
            document.getElementById('registerForm').style.display = 'block';
        });

        document.getElementById('switchToLogin').addEventListener('click', () => {
            document.getElementById('registerForm').style.display = 'none';
            document.getElementById('loginForm').style.display = 'block';
        });

        document.getElementById('logoutBtn').addEventListener('click', async () => {
            await firebase.auth().signOut();
        });

        document.getElementById('subscriptionBtn').addEventListener('click', () => {
            window.open(`${this.apiBaseUrl}/subscription/create-checkout`, '_blank');
        });
    }

    getApiBaseUrl() {
        // Check for API_URL in window config or use default
        if (window.CICERO_API_URL) {
            return window.CICERO_API_URL;
        }
        
        // Default to localhost for development
        return 'http://127.0.0.1:8000';
    }

    init() {
        this.setupEventListeners();
        this.renderMessages();
        this.updateStateSelector();
        this.updateCharCount();
    }

    setupEventListeners() {
        const form = document.getElementById('chatForm');
        const input = document.getElementById('messageInput');
        const stateSelector = document.getElementById('stateSelector');
        const clearBtn = document.getElementById('clearChatBtn');
        const exampleBtns = document.querySelectorAll('.example-btn');

        form.addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleSendMessage();
        });

        input.addEventListener('input', () => {
            this.updateCharCount();
            this.autoResizeTextarea(input);
        });

        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                if (!this.isLoading) {
                    this.handleSendMessage();
                }
            }
        });

        stateSelector.addEventListener('change', (e) => {
            this.selectedState = e.target.value;
            this.saveState(this.selectedState);
        });

        clearBtn.addEventListener('click', () => {
            this.clearChat();
        });

        exampleBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                const question = btn.getAttribute('data-question');
                input.value = question;
                this.updateCharCount();
                this.handleSendMessage();
            });
        });
    }

    autoResizeTextarea(textarea) {
        textarea.style.height = 'auto';
        textarea.style.height = Math.min(textarea.scrollHeight, 200) + 'px';
    }

    updateCharCount() {
        const input = document.getElementById('messageInput');
        const charCount = document.getElementById('charCount');
        const count = input.value.length;
        charCount.textContent = `${count} / 2000`;
        charCount.classList.toggle('char-count-warning', count > 1800);
    }

    updateStateSelector() {
        const selector = document.getElementById('stateSelector');
        selector.value = this.selectedState;
    }

    async handleSendMessage() {
        const input = document.getElementById('messageInput');
        const message = input.value.trim();
        
        if (!message || this.isLoading) return;

        // Hide welcome message
        const welcomeMsg = document.getElementById('welcomeMessage');
        if (welcomeMsg) {
            welcomeMsg.style.display = 'none';
        }

        // Add user message
        this.addMessage(message, 'user');
        input.value = '';
        this.updateCharCount();
        this.autoResizeTextarea(input);

        // Show loading
        this.setLoading(true);

        try {
            // Build history from existing messages
            const history = this.messages
                .filter(msg => msg.role !== 'system')
                .map(msg => ({
                    role: msg.role,
                    content: msg.content
                }));

            // Get fresh token
            if (this.currentUser) {
                this.authToken = await this.currentUser.getIdToken();
            }

            // Send to API
            const headers = {
                'Content-Type': 'application/json',
            };
            if (this.authToken) {
                headers['Authorization'] = `Bearer ${this.authToken}`;
            }

            const response = await fetch(`${this.apiBaseUrl}/chat`, {
                method: 'POST',
                headers: headers,
                body: JSON.stringify({
                    message: message,
                    state: this.selectedState,
                    history: history
                })
            });

            if (!response.ok) {
                throw new Error(`Server error: ${response.status}`);
            }

            const data = await response.json();
            
            // Add assistant response
            let assistantContent = data.response || 'I apologize, but I couldn\'t generate a response.';
            
            // Add citations if available
            if (data.citations && data.citations.length > 0) {
                assistantContent += '\n\n**Sources:**\n' + data.citations.map((cite, i) => `${i + 1}. ${cite}`).join('\n');
            }

            this.addMessage(assistantContent, 'assistant');
            
        } catch (error) {
            console.error('Error sending message:', error);
            this.addMessage(
                `I'm having trouble connecting to the server. Please make sure the backend is running at ${this.apiBaseUrl}`,
                'assistant',
                true
            );
        } finally {
            this.setLoading(false);
        }
    }

    addMessage(content, role, isError = false) {
        const message = {
            content: content,
            role: role,
            timestamp: new Date().toISOString()
        };

        this.messages.push(message);
        this.saveMessages();
        this.renderMessages();
        this.scrollToBottom();
    }

    renderMessages() {
        const container = document.getElementById('messages');
        container.innerHTML = '';

        this.messages.forEach((msg, index) => {
            const messageEl = this.createMessageElement(msg, index);
            container.appendChild(messageEl);
        });
    }

    createMessageElement(msg, index) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message message-${msg.role}`;
        
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        
        // Format message content (simple markdown-like formatting)
        const formattedContent = this.formatMessage(msg.content);
        contentDiv.innerHTML = formattedContent;
        
        messageDiv.appendChild(contentDiv);
        
        return messageDiv;
    }

    formatMessage(text) {
        // Simple markdown-like formatting
        let formatted = text
            // Escape HTML
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            // Bold
            .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
            // Italic
            .replace(/\*(.+?)\*/g, '<em>$1</em>')
            // Code blocks
            .replace(/`(.+?)`/g, '<code>$1</code>')
            // Line breaks
            .replace(/\n/g, '<br>')
            // Links (basic)
            .replace(/(https?:\/\/[^\s]+)/g, '<a href="$1" target="_blank" rel="noopener">$1</a>');
        
        return formatted;
    }

    setLoading(loading) {
        this.isLoading = loading;
        const indicator = document.getElementById('loadingIndicator');
        const sendBtn = document.getElementById('sendBtn');
        
        if (loading) {
            indicator.style.display = 'flex';
            sendBtn.disabled = true;
            sendBtn.classList.add('disabled');
        } else {
            indicator.style.display = 'none';
            sendBtn.disabled = false;
            sendBtn.classList.remove('disabled');
        }
        
        this.scrollToBottom();
    }

    scrollToBottom() {
        setTimeout(() => {
            const container = document.getElementById('chatContainer');
            container.scrollTop = container.scrollHeight;
        }, 100);
    }

    clearChat() {
        if (confirm('Are you sure you want to clear the chat history?')) {
            this.messages = [];
            this.saveMessages();
            this.renderMessages();
            
            // Show welcome message again
            const welcomeMsg = document.getElementById('welcomeMessage');
            if (welcomeMsg) {
                welcomeMsg.style.display = 'block';
            }
        }
    }

    // Local Storage
    saveMessages() {
        try {
            localStorage.setItem('cicero_messages', JSON.stringify(this.messages));
        } catch (e) {
            console.warn('Could not save messages to localStorage:', e);
        }
    }

    loadMessages() {
        try {
            const saved = localStorage.getItem('cicero_messages');
            return saved ? JSON.parse(saved) : [];
        } catch (e) {
            console.warn('Could not load messages from localStorage:', e);
            return [];
        }
    }

    saveState(state) {
        try {
            localStorage.setItem('cicero_state', state);
        } catch (e) {
            console.warn('Could not save state to localStorage:', e);
        }
    }

    loadState() {
        try {
            return localStorage.getItem('cicero_state');
        } catch (e) {
            console.warn('Could not load state from localStorage:', e);
            return null;
        }
    }
}

// Initialize app when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.ciceroApp = new CiceroApp();
    });
} else {
    window.ciceroApp = new CiceroApp();
}

