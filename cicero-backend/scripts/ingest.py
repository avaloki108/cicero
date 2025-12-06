import os
import time
from pinecone import Pinecone
from dotenv import load_dotenv

# Load keys
load_dotenv()

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
INDEX_NAME = "cicero-knowledge"

# Initialize Pinecone
pc = Pinecone(api_key=PINECONE_API_KEY)
index = pc.Index(INDEX_NAME)

def ingest_text_file(filepath: str, namespace: str = "general"):
    """Reads a text file and uploads it to Pinecone Inference."""
    filename = os.path.basename(filepath)
    print(f"📖 Reading {filename}...")
    
    with open(filepath, "r", encoding="utf-8") as f:
        text = f.read()
    
    # We chunk the text because models have limits (e.g. 1024 tokens)
    # Simple chunking for now (approx 3000 chars ~ 750 tokens)
    chunk_size = 3000
    chunks = [text[i:i+chunk_size] for i in range(0, len(text), chunk_size)]
    
    print(f"🧩 Split into {len(chunks)} chunks. Uploading...")
    
    records = []
    for i, chunk in enumerate(chunks):
        record = {
            "id": f"{filename}_chunk_{i}",
            "text": chunk, # <--- The Inference API automatically embeds this!
            "metadata": {
                "filename": filename,
                "chunk_index": i,
                "source": "local_upload"
            }
        }
        records.append(record)
        
    # Upsert in batches
    try:
        index.upsert_records(namespace=namespace, records=records)
        print(f"✅ Successfully stored {filename} in Cicero's memory.")
    except Exception as e:
        print(f"❌ Error uploading {filename}: {e}")

if __name__ == "__main__":
    # Create a 'documents' folder if it doesn't exist
    docs_dir = "documents"
    if not os.path.exists(docs_dir):
        os.makedirs(docs_dir)
        print(f"📂 Created '{docs_dir}' folder. Put your legal text files there!")
    else:
        # Scan folder for .txt or .md files
        files = [f for f in os.listdir(docs_dir) if f.endswith((".txt", ".md"))]
        if not files:
            print(f"⚠️ No files found in '{docs_dir}'. Add some .txt files to ingest.")
        else:
            print(f"📚 Found {len(files)} documents.")
            for file in files:
                ingest_text_file(os.path.join(docs_dir, file))