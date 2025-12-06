import httpx
from langchain_core.tools import tool
from app.config import settings
from typing import Optional, List, Dict


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
    Search for real US court opinions and case law.
    Arguments:
      query: The legal topic or keywords (e.g. "traffic stop probable cause").
      jurisdiction: Optional. The court ID (e.g., "scotus" for Supreme Court, "ca9" for 9th Circuit).
                    Leave empty to search all US courts.
    """
    url = "https://www.courtlistener.com/api/rest/v3/search/"
    headers = {"Authorization": f"Token {settings.COURTLISTENER_API_KEY}"}
    params = {
        "q": query,
        "type": "o",  # 'o' = Opinion
        "order_by": "score desc",
        "stat_Precedential": "on",  # Only cite precedential cases
    }
    if jurisdiction:
        params["court"] = jurisdiction

    data = await fetch_json(url, params, headers)

    if "error" in data:
        return f"Error searching cases: {data['error']}"

    results = data.get("results", [])
    if not results:
        return "No relevant case law found."

    # Format the top 3 cases for Cicero to read
    formatted_cases = []
    for case in results[:3]:
        name = case.get("caseName", "Unknown Case")
        citation = case.get("citation", ["No citation"])[0]
        snippet = case.get("snippet", "No summary available.")
        date = case.get("dateFiled", "Unknown date")
        formatted_cases.append(
            f"CASE: {name} ({date})\nCITATION: {citation}\nSUMMARY: {snippet}\n---"
        )

    return "\n".join(formatted_cases)


# --- TOOL 2: Statutes (LegiScan) ---
@tool
async def search_statutes(query: str, state: str = "US") -> str:
    """
    Search for legislation, bills, and statutes in a specific US State or Federal Congress.
    Arguments:
      query: Keywords for the law (e.g. "tenant eviction notice").
      state: The 2-letter state code (e.g. "CA", "TX", "NY"). Use "US" for Federal.
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
        return "No statutes found matching that query."

    # 2. Get details for the top result
    results = search_data.get("searchresult", {})
    # LegiScan returns a weird dict structure, we just want the first result that isn't metadata
    bills = [v for k, v in results.items() if k != "summary"]

    if not bills:
        return "No specific bills found."

    top_bill = bills[0]
    bill_id = top_bill.get("bill_id")

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
