import httpx
from langchain_core.tools import tool
from app.config import settings
from typing import Optional, List, Dict


# State abbreviation to CourtListener court ID mapping
# Focus on main appellate/supreme courts + federal courts for each state
STATE_TO_COURT = {
    # California - Supreme, Appeals, Federal
    "CA": [
        "cal",
        "calctapp",
        "calctapp1d",
        "calctapp2d",
        "calctapp3d",
        "calctapp4d",
        "calctapp5d",
        "calctapp6d",
        "ca9",
        "cacd",
        "caed",
        "cand",
        "casd",
        "cacb",
        "caeb",
        "canb",
        "casb",
    ],
    
    # Colorado - Supreme, Appeals, Federal  
    "CO": ["colo", "coloctapp", "coldistct", "cod", "cob"],
    
    # New York - Court of Appeals, Appellate Div, Supreme, Federal
    "NY": [
        "ny",
        "nyappdiv",
        "nyappterm",
        "nysupct",
        "ca2",
        "nyed",
        "nynd",
        "nysd",
        "nywd",
        "nyeb",
        "nynb",
        "nysb",
        "nywb",
    ],
    
    # Texas - Supreme, Criminal Appeals, Civil Appeals, Federal
    "TX": [
        "tex",
        "texcrimapp",
        "texapp",
        "txed",
        "txnd",
        "txsd",
        "txwd",
        "txeb",
        "txnb",
        "txsb",
        "txwb",
    ],
    
    # Florida - Supreme, District Courts of Appeal, Federal
    "FL": [
        "fla",
        "fladistctapp",
        "fladistctapp1",
        "fladistctapp2",
        "fladistctapp3",
        "fladistctapp4",
        "fladistctapp5",
        "fladistctapp6",
        "flmd",
        "flnd",
        "flsd",
        "flmb",
        "flnb",
        "flsb",
    ],
    
    # Federal courts (US-wide)
    "US": [
        "scotus",
        "ca1",
        "ca2",
        "ca3",
        "ca4",
        "ca5",
        "ca6",
        "ca7",
        "ca8",
        "ca9",
        "ca10",
        "ca11",
        "cadc",
        "cafc",
    ],
}


# --- Helper for HTTP Requests ---
async def fetch_json(url: str, params: dict = None, headers: dict = None) -> Dict:
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                url, params=params, headers=headers, timeout=10.0
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"error": str(e)}


# --- TOOL 1: Case Law (CourtListener) ---
@tool
async def search_case_law(query: str, jurisdiction: str = None) -> str:
    """
    Search for real US court opinions and case law from CourtListener database.
    
    Arguments:
      query: Legal search terms. USE LEGAL TERMINOLOGY for best results!
             Good examples: "fourth amendment search seizure", "miranda rights", 
             "probable cause vehicle", "DUI blood draw", "Terry stop frisk"
             Bad examples: "traffic stop rights", "what are my rights" (too vague)
      jurisdiction: Optional. A 2-letter state code (e.g., "CO", "CA", "TX") to search that state's courts,
                    or "US" for federal courts. Leave empty to search all US courts.
    
    Tips: Convert user questions to legal concepts. "pulled over rights" -> "fourth amendment traffic stop"
    """
    # Use v4 API
    url = "https://www.courtlistener.com/api/rest/v4/search/"
    headers = {"Authorization": f"Token {settings.COURTLISTENER_API_KEY}"}
    params = {
        "q": query,
        "type": "o",  # Opinion search type
    }
    
    print(f"--- Case law query: '{query}' ---")
    
    # Convert state abbreviation to CourtListener court IDs
    if jurisdiction and jurisdiction.upper() in STATE_TO_COURT:
        courts = STATE_TO_COURT[jurisdiction.upper()]
        params["court"] = courts  # httpx encodes lists as repeated params (court=a&court=b)
        print(f"--- Searching courts: {','.join(courts)} ---")
    elif jurisdiction:
        # Accept a comma-separated list or a single direct CourtListener ID
        courts = [c.strip() for c in jurisdiction.split(",") if c.strip()]
        params["court"] = courts if len(courts) > 1 else courts[0]
        print(f"--- Searching courts: {jurisdiction} ---")

    data = await fetch_json(url, params, headers)
    print(f"--- CourtListener response count: {data.get('count', 'N/A')} ---")

    if "error" in data:
        return f"Error searching cases: {data['error']}"

    results = data.get("results", [])
    if not results:
        return "No relevant case law found."

    # Format the top 3 cases for Cicero to read
    formatted_cases = []
    for case in results[:3]:
        name = case.get("caseName", "Unknown Case")
        # citation can be None or a list
        citation_list = case.get("citation")
        citation = citation_list[0] if citation_list else case.get("docketNumber", "No citation")
        
        # In v4 API, snippet is often in opinions[0].snippet
        snippet = None
        opinions = case.get("opinions", [])
        if opinions and len(opinions) > 0:
            snippet = opinions[0].get("snippet")
        if not snippet:
            snippet = case.get("snippet") or case.get("syllabus") or case.get("suitNature") or "No summary available - see full case for details."
        
        date = case.get("dateFiled", "Unknown date")
        court = case.get("court", "Unknown court")
        formatted_cases.append(
            f"CASE: {name} ({date})\nCOURT: {court}\nCITATION: {citation}\nSUMMARY: {snippet}\n---"
        )

    return "\n".join(formatted_cases)


# --- TOOL 2: Statutes (LegiScan) ---
@tool
async def search_statutes(query: str, state: str = "US") -> str:
    """
    Search for RECENT legislation and bills (last ~2 years) in a specific US State or Federal Congress.
    
    IMPORTANT: This searches for RECENT BILLS, not established statutes or legal codes.
    For established legal concepts (like "statute of limitations", "eviction requirements", etc.),
    use search_case_law instead.
    
    Arguments:
      query: Keywords for the recent bill/legislation (e.g. "new tenant protection bill").
      state: The 2-letter state code (e.g. "CA", "TX", "NY"). Use "US" for Federal.
    
    Best for: Recently introduced bills, pending legislation, new laws being considered.
    NOT for: Established legal concepts, state codes, long-standing statutes.
    """
    # 1. Search for the Bill/Statute ID
    search_url = "https://api.legiscan.com/"
    search_params = {
        "key": settings.LEGISCAN_API_KEY,
        "op": "getSearch",
        "state": state,
        "query": query,
        "year": 2,  # Search recent archives (last ~2 years)
    }

    search_data = await fetch_json(search_url, search_params)

    if search_data.get("status") != "OK":
        return "No recent bills found matching that query. Note: This tool searches for recent bills (last 2 years), not established statutes. For established legal concepts, case law searches may be more appropriate."

    # 2. Get details for the top result
    results = search_data.get("searchresult", {})
    # LegiScan returns a weird dict structure, we just want the first result that isn't metadata
    bills = [v for k, v in results.items() if k != "summary"]

    if not bills:
        return "No specific bills found. Note: This tool searches for recent bills (last 2 years), not established statutes."

    top_bill = bills[0]
    bill_id = top_bill.get("bill_id")
    
    # Check if the bill title/description seems relevant to the query
    bill_title = top_bill.get("title", "").lower()
    query_lower = query.lower()
    query_words = set(query_lower.split())
    
    # Simple relevance check - if the bill title doesn't contain key query terms, warn
    title_words = set(bill_title.split())
    relevant_terms = query_words & title_words
    if len(relevant_terms) == 0 and len(query_words) > 2:
        # Bill might not be relevant, but we'll still return it with a note
        print(f"--- Warning: Bill '{bill_title}' may not be directly relevant to query '{query}' ---")

    # 3. Fetch full text/summary of that bill
    details_url = "https://api.legiscan.com/"
    details_params = {"key": settings.LEGISCAN_API_KEY, "op": "getBill", "id": bill_id}
    details_data = await fetch_json(details_url, details_params)

    if details_data.get("status") == "OK":
        bill = details_data["bill"]
        title = bill.get("title", "")
        desc = bill.get("description", "")
        status = bill.get("status_date", "")
        return (
            f"STATUTE/BILL: {title}\nSTATE: {state}\nSTATUS: {status}\nSUMMARY: {desc}"
        )

    return f"Found bill {top_bill.get('bill_number')} but could not retrieve details."
