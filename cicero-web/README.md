# Cicero Web App

A modern, responsive web interface for the Cicero AI Legal Assistant.

## Features

- 💬 **Chat Interface**: Clean, modern chat UI with message history
- 🗺️ **State Selection**: Choose your state for location-specific legal information
- 💾 **Local Storage**: Chat history persists in browser
- 📱 **Responsive Design**: Works on desktop, tablet, and mobile devices
- ⚡ **Real-time Updates**: Loading indicators and smooth animations
- 🎨 **Modern UI**: Clean, professional design with smooth transitions

## Getting Started

### Prerequisites

- A running Cicero backend server (default: `http://127.0.0.1:8000`)
- A modern web browser

### Running Locally

1. **Start the backend server** (if not already running):
   ```bash
   cd cicero-backend
   uvicorn main:app --reload
   ```

2. **Start the web server**:
   ```bash
   cd cicero-web
   python server.py
   ```
   
   Or use any other local web server:
   ```bash
   # Python 3 built-in
   python -m http.server 3000
   
   # Node.js (if you have http-server installed)
   npx http-server -p 3000
   ```

3. **Access the app**:
   - The server will automatically open your browser
   - Or navigate to `http://localhost:3000`

### Configuration

The app automatically connects to `http://127.0.0.1:8000` by default. To change this:

1. **For development**: Edit `app.js` and change the `getApiBaseUrl()` method
2. **For production**: Set the `VITE_API_URL` environment variable (if using a build tool)

## Usage

1. **Select your state**: Use the dropdown in the header to select your state
2. **Ask questions**: Type your legal question in the input box and press Enter or click Send
3. **View responses**: Messages appear in the chat with proper formatting
4. **Clear chat**: Click the trash icon to clear your chat history
5. **Try examples**: Click on example questions to get started quickly

## File Structure

```
cicero-web/
├── index.html      # Main HTML structure
├── app.js          # Application logic and API integration
├── styles.css      # Styling and responsive design
├── favicon.png     # App icon
└── README.md       # This file
```

## API Integration

The app connects to the Cicero FastAPI backend:

- **POST `/chat`**: Send messages and receive responses
  - Request: `{ message: string, state: string, history: array }`
  - Response: `{ response: string, citations: array }`

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Features in Detail

### Chat Interface
- Message bubbles with distinct styling for user and assistant
- Auto-scrolling to latest message
- Markdown-like formatting support (bold, italic, code, links)
- Character counter for input

### State Selection
- All 50 US states plus DC
- Selection persists in localStorage
- State-specific legal information

### Local Storage
- Chat history saved automatically
- State preference saved
- Cleared when user clicks "Clear Chat"

### Responsive Design
- Mobile-first approach
- Adapts to different screen sizes
- Touch-friendly interface

## Development

### Adding Features

To add new features:

1. **UI Components**: Add HTML in `index.html`
2. **Styling**: Add CSS in `styles.css`
3. **Functionality**: Add JavaScript in `app.js`

### API Endpoints

The app currently uses:
- `/chat` - Main chat endpoint

Additional endpoints available:
- `/rag/context` - Get RAG context for a query
- `/` - Health check

## Troubleshooting

### Can't connect to backend
- Make sure the backend is running on port 8000
- Check CORS settings in the backend
- Verify the API URL in `app.js`

### Messages not saving
- Check browser console for errors
- Ensure localStorage is enabled
- Try clearing browser cache

### Styling issues
- Clear browser cache
- Check for CSS conflicts
- Verify all CSS files are loaded

## License

Part of the Cicero project.

