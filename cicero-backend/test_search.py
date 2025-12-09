import asyncio
import httpx
from app.config import settings

async def test_courtlistener():
    print("Testing CourtListener API directly...")
    url = "https://www.courtlistener.com/api/rest/v3/search/"
    headers = {"Authorization": f"Token {settings.COURTLISTENER_API_KEY}"}
    params = {
        "q": "traffic stop",
        "type": "o",
        "court": "colo,coloctapp",
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=params, headers=headers, timeout=10.0)
        data = response.json()
        print(f"Status: {response.status_code}")
        print(f"Count: {data.get('count', 0)}")
        results = data.get("results", [])
        print(f"Results returned: {len(results)}")
        if results:
            for case in results[:2]:
                print(f"  - {case.get('caseName')}")
        else:
            print("Raw response:", data)

if __name__ == "__main__":
    asyncio.run(test_courtlistener())
