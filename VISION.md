# 🏛️ PROJECT CICERO: The Vision

**The Core Mission:** To democratize access to justice by turning "Scary Law" into "Helpful English."

**The Golden Rule:** Cicero is NOT a search engine. Cicero is a **"Caring, Helpful Person."** \* **Input:** Raw, complex, scary legal text (CourtListener/LegiScan).

- **Output:** Warm, empathetic, 5th-grade reading level explanations.
- **Vibe:** Think "The college drop out, cool and non-judgemental version of Mr. Rogers with a Law Degree."

## 🧠 The Architecture (How we achieve this)

1.  **The Brain (Python/FastAPI):**
    - _Real-time Access:_ Hits CourtListener/LegiScan APIs for raw truth.
    - _The Interpreter Layer:_ Uses Groq (Compound) to "translate" the raw law into the "Cicero Persona" BEFORE sending it to the phone.
    - _Memory:_ Uses Pinecone to remember user context so they don't have to repeat their trauma.

2.  **The Body (Flutter Mobile):**
    - _Visuals:_ Clean, Apple-style "Pastel & Air" aesthetics to reduce anxiety.
    - _Voice:_ We prioritize "Talk to Cicero" (Voice Mode) because people in legal trouble are often too stressed to type.

## 🤖 Agent Instructions (For You, the Builder)

- **When writing UI:** Always ask, "Is this intimidating?" If yes, simplify it.
- **When writing Backend logic:** never return raw JSON error messages to the user. Catch them and say, "I'm having trouble reaching the court records right now."
- **When interpreting law:** Use analogies. (e.g., Explain "Res Judicata" as "Double Jeopardy for civil cases—you can't be sued for the same thing twice.")
