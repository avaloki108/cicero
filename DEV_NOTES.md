# Cicero Development Status & Notes

## 1. Backend Brain (Agent Persona)
- **Status:** ✅ Completed
- **Persona:** "Cool, non-judgemental Mr. Rogers with a Law Degree".
- **Capabilities:**
  - 5th-grade reading level "Plain English" translation.
  - Empathetic responses strictly enforced.
  - Uses analogies (e.g., "Double Jeopardy" for civil cases).
  - Tools enabled: `search_statutes`, `search_case_law`.
- **Architecture:**
  - **Graph:** Async LangGraph with `add_messages` reducer.
  - **Loop prevention:** Explicit tool protocol in system prompt to prevent XML/mixed-content errors.
  - **Port:** Running on `8013` (needs standardization).

## 2. Frontend Body (Mobile App)
- **Status:** ✅ Integrated & Running (Linux Desktop verified)
- **State Management:** Riverpod + Hive (Local Storage).
- **API Client:**
  - Updated to point to `10.0.2.2:8013` (Android) / `127.0.0.1:8013` (Linux).
  - Sends `message` and `state`.
- **Voice Mode:**
  - `voice_service.dart` patched to disable permission checks on Desktop (prevents crashes).
  - Only active on Android/iOS.
- **UI:** rendering Markdown responses correctly.

## 3. Critical Integration Gaps (Next Steps)
### A. Conversation Memory (The "Goldfish" Problem)
- **Issue:** The backend currently treats every request as a new conversation.
- **Fix:**
  1.  **Frontend:** Update `chat_state_notifier.dart` to format and send `history` list in the API request.
  2.  **Backend:** Update `main.py` to parse `request.history` into LangChain message objects (`HumanMessage`, `AIMessage`) and pass them into the graph's `inputs`.

### B. Citation Handling
- **Issue:** Backend returns `citations: []` in the JSON response, relying on the text body to contain sources.
- **Fix:**
  - **Option 1 (Quick):** Rely on inline text citations (Agent already does this).
  - **Option 2 (Robust):** Update `agent.py` to extract used tools/results and populate the `citations` key in the final state.

### C. Port Standardization
- The backend port keeps changing (`8013` currently). We should fix it to `8000` or use a reliable `.env` variable for both frontend and backend.

## 4. How to Run
### Backend
```bash
cd cicero-backend
./venv/bin/uvicorn main:app --host 0.0.0.0 --port 8013
```

### Mobile (Linux)
```bash
cd cicero-mobile
flutter run -d linux
```
