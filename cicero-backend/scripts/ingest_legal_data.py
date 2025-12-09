"""
Pull recent legal data and index it into Pinecone for RAG.

Currently implemented:
 - CourtListener opinions (v4 API) with full text retrieval.

Usage:
    python scripts/ingest_legal_data.py \
        --source courtlistener \
        --days-back 3 \
        --limit 30 \
        --namespace case-law
"""

import argparse
import datetime as dt
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional

import httpx

# Allow running as a script (`python scripts/ingest_legal_data.py`)
if __package__ is None and __name__ == "__main__":
    sys.path.append(str(Path(__file__).resolve().parents[1]))

from scripts.ingestion_utils import build_records, get_pinecone_index


# --- Helpers -----------------------------------------------------------------
def _auth_headers() -> Dict[str, str]:
    token = os.getenv("COURTLISTENER_API_KEY")
    headers: Dict[str, str] = {}
    if token:
        headers["Authorization"] = f"Token {token}"
    return headers


# --- CourtListener -----------------------------------------------------------
def fetch_opinion_text(opinion_id: int, client: httpx.Client) -> Optional[str]:
    """Fetch the full text for a single opinion."""
    url = f"https://www.courtlistener.com/api/rest/v4/opinions/{opinion_id}/"
    resp = client.get(url, headers=_auth_headers(), timeout=20.0)
    if resp.status_code != 200:
        print(f"[warn] Could not fetch opinion {opinion_id}: {resp.status_code}")
        return None

    data = resp.json()
    text = (
        data.get("html_with_citations")
        or data.get("plain_text")
        or data.get("html")
        or ""
    )
    return text


def fetch_recent_courtlistener(
    days_back: int = 3, page_size: int = 20, limit: int = 50
) -> List[Dict]:
    """Fetch recent opinions from CourtListener search API and return raw docs."""
    base_url = "https://www.courtlistener.com/api/rest/v4/search/"
    date_min = (dt.date.today() - dt.timedelta(days=days_back)).isoformat()

    params = {
        "type": "o",
        "page_size": page_size,
        "date_filed_min": date_min,
    }

    docs: List[Dict] = []
    cursor = None

    with httpx.Client() as client:
        while True:
            if cursor:
                params["cursor"] = cursor

            resp = client.get(base_url, headers=_auth_headers(), params=params, timeout=20.0)
            if resp.status_code != 200:
                print(f"[warn] CourtListener search failed: {resp.status_code} {resp.text[:120]}")
                break

            data = resp.json()
            results = data.get("results", [])
            for case in results:
                if len(docs) >= limit:
                    return docs

                opinions = case.get("opinions") or []
                if not opinions:
                    continue

                # Grab the lead opinion (first in list) for text
                opinion_id = opinions[0].get("id")
                opinion_text = fetch_opinion_text(opinion_id, client) if opinion_id else None
                if not opinion_text:
                    continue

                citation_list = case.get("citation") or []
                citation = citation_list[0] if citation_list else case.get("docketNumber", "")

                doc = {
                    "id": f"courtlistener-{opinion_id}",
                    "text": opinion_text,
                    "metadata": {
                        "source": "CourtListener",
                        "docType": "case",
                        "title": case.get("caseName") or citation or f"Opinion {opinion_id}",
                        "citation": citation,
                        "court": case.get("court"),
                        "dateFiled": case.get("dateFiled"),
                        "absolute_url": case.get("absolute_url"),
                        "cluster_id": case.get("cluster_id"),
                        "opinion_id": opinion_id,
                    },
                }
                docs.append(doc)

            cursor = data.get("next")
            if not cursor or len(docs) >= limit:
                break

    return docs


# --- LegiScan ---------------------------------------------------------------
def fetch_legiscan_bills(
    states: List[str], query: str, max_per_state: int = 10
) -> List[Dict]:
    """Fetch bills from LegiScan using getSearch and then getBill for details."""
    api_key = os.getenv("LEGISCAN_API_KEY")
    if not api_key:
        print("[warn] LEGISCAN_API_KEY missing; skipping LegiScan.")
        return []

    base_url = "https://api.legiscan.com/"
    docs: List[Dict] = []

    with httpx.Client() as client:
        for state in states:
            search_params = {
                "key": api_key,
                "op": "getSearch",
                "state": state,
                "query": query,
                "year": 2,  # last ~2 years
            }
            resp = client.get(base_url, params=search_params, timeout=20.0)
            data = resp.json() if resp.status_code == 200 else {}
            if data.get("status") != "OK":
                print(f"[warn] LegiScan search failed for {state}: {resp.status_code}")
                continue

            search_results = data.get("searchresult", {})
            bills = [v for k, v in search_results.items() if k != "summary"]
            bills = bills[:max_per_state]

            for bill in bills:
                bill_id = bill.get("bill_id")
                if not bill_id:
                    continue

                detail_params = {"key": api_key, "op": "getBill", "id": bill_id}
                detail_resp = client.get(base_url, params=detail_params, timeout=20.0)
                detail_data = detail_resp.json() if detail_resp.status_code == 200 else {}
                bill_detail = detail_data.get("bill")
                if not bill_detail:
                    continue

                title = bill_detail.get("title", "")
                desc = bill_detail.get("description", "")

                text = f"{title}\n\n{desc}"
                docs.append(
                    {
                        "id": f"legiscan-{bill_id}",
                        "text": text,
                        "metadata": {
                            "source": "LegiScan",
                            "docType": "bill",
                            "title": title,
                            "description": desc,
                            "state": bill_detail.get("state"),
                            "bill_number": bill_detail.get("bill_number"),
                            "session": bill_detail.get("session", {}).get("session_name"),
                            "url": bill_detail.get("url"),
                            "status_date": bill_detail.get("status_date"),
                        },
                    }
                )

    return docs


# --- Congress.gov -----------------------------------------------------------
def fetch_congress_bills(limit: int = 20) -> List[Dict]:
    """Fetch recent bills from Congress.gov API."""
    api_key = os.getenv("CONGRESS_GOV_API_KEY")
    if not api_key:
        print("[warn] CONGRESS_GOV_API_KEY missing; skipping Congress.gov.")
        return []

    base_url = "https://api.congress.gov/v3/bill"
    params = {"api_key": api_key, "format": "json", "limit": limit}

    docs: List[Dict] = []
    with httpx.Client() as client:
        resp = client.get(base_url, params=params, timeout=20.0)
        data = resp.json() if resp.status_code == 200 else {}
        bills = data.get("bills", [])
        for bill in bills:
            latest_action = (bill.get("latestAction") or {}).get("text", "")
            action_date = (bill.get("latestAction") or {}).get("actionDate")
            title = bill.get("title") or bill.get("title", "")
            text = f"{title}\n\nLatest action: {latest_action} ({action_date})"
            docs.append(
                {
                    "id": f"congress-{bill.get('congress')}-{bill.get('number')}",
                    "text": text,
                    "metadata": {
                        "source": "Congress.gov",
                        "docType": "bill",
                        "title": title,
                        "bill_number": bill.get("number"),
                        "congress": bill.get("congress"),
                        "originChamber": bill.get("originChamber"),
                        "url": bill.get("url"),
                        "latestAction": latest_action,
                        "latestActionDate": action_date,
                    },
                }
            )

    return docs


# --- Ingestion driver -------------------------------------------------------
def upsert_docs(docs: List[Dict], namespace: str, chunk_size: int, chunk_overlap: int) -> None:
    index, index_name = get_pinecone_index()
    print(f"[info] Target index: {index_name}")

    total_records = 0
    for doc in docs:
        records = build_records(
            base_id=doc["id"],
            text=doc["text"],
            metadata=doc["metadata"],
            chunk_size=chunk_size,
            overlap=chunk_overlap,
        )
        if not records:
            continue
        index.upsert_records(namespace=namespace, records=records)
        total_records += len(records)

    print(f"[done] Upserted {total_records} records from {len(docs)} documents into '{namespace}'.")


def main():
    parser = argparse.ArgumentParser(description="Ingest legal data into Pinecone.")
    parser.add_argument(
        "--source",
        choices=["courtlistener", "legiscan", "congress", "all"],
        default="courtlistener",
        help="Data source to ingest.",
    )
    parser.add_argument("--namespace", default="case-law", help="Pinecone namespace.")
    parser.add_argument("--days-back", type=int, default=3, help="CourtListener look back window.")
    parser.add_argument("--limit", type=int, default=50, help="Max documents to ingest.")
    parser.add_argument("--page-size", type=int, default=20, help="CourtListener page size.")
    parser.add_argument(
        "--legiscan-states",
        nargs="*",
        default=["CA", "TX", "NY", "FL"],
        help="States to pull from LegiScan.",
    )
    parser.add_argument(
        "--legiscan-query",
        default="tenant OR eviction OR privacy",
        help="LegiScan search query (basic keyword query).",
    )
    parser.add_argument("--chunk-size", type=int, default=3000, help="Chunk size for splitting text.")
    parser.add_argument("--chunk-overlap", type=int, default=200, help="Token overlap between chunks.")

    args = parser.parse_args()

    docs: List[Dict] = []

    if args.source in ("courtlistener", "all"):
        print(f"[info] Fetching CourtListener opinions (last {args.days_back} days)...")
        docs.extend(
            fetch_recent_courtlistener(
                days_back=args.days_back,
                page_size=args.page_size,
                limit=args.limit,
            )
        )

    if args.source in ("legiscan", "all"):
        print(f"[info] Fetching LegiScan bills for states {args.legiscan_states}...")
        docs.extend(
            fetch_legiscan_bills(
                states=args.legiscan_states,
                query=args.legiscan_query,
                max_per_state=max(1, args.limit // max(1, len(args.legiscan_states))),
            )
        )

    if args.source in ("congress", "all"):
        print("[info] Fetching Congress.gov bills...")
        docs.extend(fetch_congress_bills(limit=args.limit))

    if not docs:
        print("[warn] No documents fetched. Check API keys and filters.")
        return

    upsert_docs(docs, namespace=args.namespace, chunk_size=args.chunk_size, chunk_overlap=args.chunk_overlap)


if __name__ == "__main__":
    main()
