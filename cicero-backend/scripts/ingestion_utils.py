import os
from pathlib import Path
from typing import Any, Dict, List, Tuple

from bs4 import BeautifulSoup
from dotenv import load_dotenv
from pinecone import Pinecone

# Load environment variables from the project root so scripts work from any cwd.
ENV_PATH = Path(__file__).resolve().parents[1] / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)
else:
    load_dotenv()


def get_pinecone_index() -> Tuple[Any, str]:
    """Return a Pinecone index instance and its name."""
    api_key = os.getenv("PINECONE_API_KEY")
    if not api_key:
        raise RuntimeError("Missing PINECONE_API_KEY. Add it to your .env file.")

    index_name = os.getenv("PINECONE_INDEX_NAME", "cicero-knowledge")
    pc = Pinecone(api_key=api_key)
    return pc.Index(index_name), index_name


def clean_text(text: str) -> str:
    """Normalize whitespace and strip HTML if present."""
    if not text:
        return ""

    stripped = text.strip()
    if "<" in stripped and "</" in stripped:
        stripped = BeautifulSoup(stripped, "html.parser").get_text("\n")

    lines = [line.strip() for line in stripped.splitlines()]
    return "\n".join([line for line in lines if line])


def chunk_text(text: str, chunk_size: int = 3000, overlap: int = 200) -> List[str]:
    """Split text into overlapping chunks."""
    if chunk_size <= overlap:
        raise ValueError("chunk_size must be greater than overlap.")

    cleaned = text.strip()
    if not cleaned:
        return []

    chunks: List[str] = []
    start = 0
    length = len(cleaned)
    while start < length:
        end = min(length, start + chunk_size)
        chunks.append(cleaned[start:end])
        start = end - overlap

    return chunks


def build_records(
    base_id: str,
    text: str,
    metadata: Dict[str, Any],
    chunk_size: int = 3000,
    overlap: int = 200,
) -> List[Dict[str, Any]]:
    """Prepare Pinecone records for a text payload."""
    cleaned = clean_text(text)
    segments = chunk_text(cleaned, chunk_size=chunk_size, overlap=overlap)

    records: List[Dict[str, Any]] = []
    for idx, chunk in enumerate(segments):
        record_meta = dict(metadata or {})
        record_meta["chunk"] = idx
        record_meta.setdefault("source", "unknown")
        record = {
            "id": f"{base_id}::chunk-{idx}",
            "text": chunk,
            "metadata": record_meta,
        }
        records.append(record)

    return records
