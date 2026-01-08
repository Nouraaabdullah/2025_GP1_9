import os
import json
import re
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

SYSTEM_PROMPT = """
You are a receipt parsing engine.

Your job:
- Extract structured data from messy OCR text of receipts
- You MUST return valid JSON only
- NEVER return explanations or text outside JSON

Rules:
1. Currency is always SAR unless stated otherwise
2. Total amount MUST be extracted if present
3. Items MUST be extracted if products are listed
4. If only one item exists, still return it as a list
5. Prices must be numbers (no text, no currency symbols)
6. Ignore phone numbers, tax numbers, staff IDs, URLs
7. Merchant name should be the shop/store name (not address)

Return JSON in this EXACT shape:

{
  "merchant": string,
  "date": "YYYY-MM-DD" | null,
  "items": [
    { "name": string, "price": number }
  ],
  "total": number,
  "currency": "SAR"
}
"""

def parse_receipt_with_llm(ocr_text: str) -> dict:
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"OCR TEXT:\n{ocr_text}\n\nExtract the receipt data."
            }
        ],
        temperature=0,
    )

    raw = response.choices[0].message.content.strip()

    # ---- SAFETY: JSON ONLY ----
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        raise ValueError("LLM did not return valid JSON")

    # ---- HARD VALIDATION / FIXES ----

    # Merchant
    if not data.get("merchant"):
        data["merchant"] = "Unknown"

    # Currency
    data["currency"] = "SAR"

    # Items
    if not isinstance(data.get("items"), list):
        data["items"] = []

    cleaned_items = []
    for item in data["items"]:
        name = str(item.get("name", "")).strip()
        price = item.get("price")

        if not name:
            continue

        try:
            price = float(price)
        except:
            continue

        cleaned_items.append({
            "name": name,
            "price": round(price, 2)
        })

    data["items"] = cleaned_items

    # Total
    try:
        data["total"] = float(data["total"])
    except:
        # Fallback: sum items
        if data["items"]:
            data["total"] = round(sum(i["price"] for i in data["items"]), 2)
        else:
            data["total"] = None

    return data
