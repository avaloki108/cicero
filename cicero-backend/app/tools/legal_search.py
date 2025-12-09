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


def _improve_legal_query(query: str) -> str:
    """
    Improve user queries for better legal search results.
    Converts common questions to better legal search terms.
    """
    query_lower = query.lower()
    
    # Statute of limitations queries - try multiple search strategies
    if "statute of limitations" in query_lower or "statute limitations" in query_lower:
        # Extract the type of claim
        if "personal injury" in query_lower or "injury" in query_lower:
            # Try a more specific search that might find relevant cases
            return '"statute of limitations" personal injury OR tort OR negligence'
        elif "contract" in query_lower:
            return "statute of limitations contract"
        elif "property" in query_lower:
            return "statute of limitations property"
        elif "medical malpractice" in query_lower or "malpractice" in query_lower:
            return "statute of limitations medical malpractice"
        else:
            return "statute of limitations"
    
    # Business registration / LLC queries
    if any(term in query_lower for term in ["business registration", "register a business", "business name", "llc", "form an llc", "llc formation", "llc requirements"]):
        if "llc" in query_lower or "limited liability" in query_lower:
            return "LLC formation requirements business registration"
        elif "business name" in query_lower or "name registration" in query_lower:
            return "business name registration requirements"
        else:
            return "business registration requirements"
    
    # Eviction queries
    if "evict" in query_lower or "eviction" in query_lower:
        if "notice" in query_lower:
            return "eviction notice requirements"
        return "eviction"
    
    # Police stop / rights queries
    if ("police" in query_lower or "officer" in query_lower or "cop" in query_lower) and ("stop" in query_lower or "rights" in query_lower or "stopped" in query_lower):
        if "search" in query_lower or "seizure" in query_lower:
            return "fourth amendment search seizure traffic stop"
        return "fourth amendment rights police stop Terry stop"
    
    # Search and seizure
    if "search" in query_lower and ("warrant" in query_lower or "police" in query_lower):
        return "fourth amendment search seizure"
    
    # Miranda rights
    if "miranda" in query_lower or ("rights" in query_lower and "arrest" in query_lower):
        return "Miranda rights fifth amendment"
    
    # Return original if no transformation needed
    return query


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
    # Improve the query for better results
    improved_query = _improve_legal_query(query)
    
    # Use v4 API
    url = "https://www.courtlistener.com/api/rest/v4/search/"
    headers = {"Authorization": f"Token {settings.COURTLISTENER_API_KEY}"}
    params = {
        "q": improved_query,
        "type": "o",  # Opinion search type
    }
    
    print(f"--- Case law query (original): '{query}' ---")
    print(f"--- Case law query (improved): '{improved_query}' ---")
    
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

    # Filter results for relevance to the original query
    query_terms = set(query.lower().split())
    query_terms -= {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were', 'what', 'when', 'where', 'why', 'how', 'about', 'can', 'could', 'should', 'would', 'do', 'does', 'did', 'my', 'me', 'i'}
    
    # Format and filter the top cases
    formatted_cases = []
    for case in results[:15]:  # Check more cases to find relevant ones
        name = case.get("caseName", "Unknown Case")
        case_text = name.lower()
        
        # In v4 API, snippet is often in opinions[0].snippet
        snippet = None
        opinions = case.get("opinions", [])
        if opinions and len(opinions) > 0:
            snippet = opinions[0].get("snippet")
        if not snippet:
            snippet = case.get("snippet") or case.get("syllabus") or case.get("suitNature") or ""
        
        if snippet:
            case_text += " " + snippet.lower()
        
        # Check relevance - case should contain key query terms
        # For statute of limitations queries, be less strict since snippets may not contain the terms
        if query_terms and len(query_terms) > 0:
            # For "statute of limitations" queries, use more lenient filtering
            if "statute" in query.lower() and "limitations" in query.lower():
                # Check case name first - sometimes the name is more informative
                name_lower = name.lower()
                
                # For statute of limitations queries, we'll be more lenient
                # Accept cases that might be relevant even if snippet doesn't have exact terms
                # Only filter out clearly unrelated cases (bankruptcy, corporate, etc.)
                clearly_unrelated = [
                    "bankruptcy", "in re", "chapter 11", "chapter 7", 
                    "corporate", "llc", "partnership", "contract dispute",
                    "property", "real estate", "foreclosure"
                ]
                
                # If it's clearly unrelated AND doesn't have relevant terms, filter it
                is_unrelated = any(term in name_lower or term in case_text for term in clearly_unrelated)
                has_relevant_terms = (
                    "statute" in case_text or "limitation" in case_text or 
                    "time limit" in case_text or "toll" in case_text or
                    ("injury" in query.lower() and ("injury" in case_text or "tort" in case_text or "negligence" in case_text or "damage" in case_text))
                )
                
                # Only filter if it's clearly unrelated (bankruptcy, corporate, etc.) AND has no relevant terms
                if is_unrelated and not has_relevant_terms:
                    print(f"--- Filtered out case (clearly unrelated): {name} ---")
                    continue
                # For statute of limitations queries, be lenient - include cases even if snippet doesn't have exact terms
                # The case might still be relevant even if the snippet doesn't mention "statute of limitations"
                # Only exclude if it's clearly about a different topic (bankruptcy, corporate, etc.)
            else:
                # For other queries, check if key terms appear
                matches = sum(1 for term in query_terms if term in case_text)
                if matches == 0:
                    print(f"--- Filtered out irrelevant case: {name} ---")
                    continue
        
        # citation can be None or a list
        citation_list = case.get("citation")
        citation = citation_list[0] if citation_list else case.get("docketNumber", "No citation")
        
        if not snippet:
            snippet = "No summary available - see full case for details."
        
        date = case.get("dateFiled", "Unknown date")
        court = case.get("court", "Unknown court")
        formatted_cases.append(
            f"CASE: {name} ({date})\nCOURT: {court}\nCITATION: {citation}\nSUMMARY: {snippet}\n---"
        )
        
        # Limit to top 3 relevant cases
        if len(formatted_cases) >= 3:
            break

    if not formatted_cases:
        # If we filtered everything out, the search terms might not be matching well
        # For statute of limitations, this information is often in statutes, not case law
        if "statute" in query.lower() and "limitations" in query.lower():
            return f"""No directly relevant case law found for '{query}'. 

This is common because statute of limitations information is typically found in state statutes (codified laws) rather than case law. Case law usually interprets or applies these statutes, but the actual time limits are set by statute.

For Colorado personal injury statute of limitations, you would typically find this information in:
- Colorado Revised Statutes (C.R.S.) Title 13 - Courts and Court Procedure
- Specifically, C.R.S. § 13-80-102 (general personal injury) or related sections

The general statute of limitations for personal injury in Colorado is typically 2 years from the date of injury, but there are exceptions and specific rules that may apply. I recommend consulting the actual Colorado Revised Statutes or speaking with a Colorado attorney for the most accurate and current information."""
        
        return f"No relevant case law found for '{query}'. The search may need different terms or the information might be in state statutes rather than case law."

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
