# backend/main.py
import os, json, datetime
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from openai import OpenAI
from dotenv import load_dotenv
import httpx
import traceback
from fastapi.responses import JSONResponse
import math
from pathlib import Path
from dotenv import load_dotenv

# Force-load backend/.env (next to main.py), not any other .env
load_dotenv(dotenv_path=Path(__file__).with_name(".env"))

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
FT_MODEL_ID    = os.getenv("FT_MODEL_ID")  # fine-tuned model id (or leave None to fall back)
SUPABASE_URL   = os.getenv("SUPABASE_URL")
SERVICE_KEY    = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
FASTAPI_SECRET = os.getenv("FASTAPI_SECRET_KEY")  # optional app-to-backend shared key
PORT           = int(os.getenv("PORT", "8080"))

if not all([OPENAI_API_KEY, SUPABASE_URL, SERVICE_KEY]):
    raise RuntimeError("Missing required env vars. Check .env")

client = OpenAI(api_key=OPENAI_API_KEY)

def _load_tools():
    path = os.path.join(os.path.dirname(__file__), "tools_data.json")
    raw = json.load(open(path, "r", encoding="utf-8"))

    tool_list = raw["tools"] if isinstance(raw, dict) and "tools" in raw else raw

    def is_openai_ready(t):
        return (
            isinstance(t, dict)
            and t.get("type") == "function"
            and isinstance(t.get("function"), dict)
            and "name" in t["function"]
        )

    tools = [t if is_openai_ready(t) else {"type": "function", "function": t} for t in tool_list]
    print("Loaded tools[0]:", tools[0])  # sanity log
    return tools

OPENAI_TOOLS = _load_tools()

# ---------- Supabase REST helpers ----------
REST = f"{SUPABASE_URL}/rest/v1"

def sbr(path: str, params: Dict[str,str] | None = None) -> List[Dict[str,Any]]:
    """GET from Supabase REST (uses service key; keep server-side only)."""
    with httpx.Client(timeout=20) as c:
        r = c.get(
            f"{REST}/{path}",
            params=params or {},
            headers={
                "apikey": SERVICE_KEY,
                "Authorization": f"Bearer {SERVICE_KEY}",
                "Accept": "application/json",
            },
        )
        if r.status_code >= 400:
            raise HTTPException(r.status_code, r.text)
        return r.json()

def sb_single(table: str, select: str, **filters) -> Optional[Dict[str,Any]]:
    params = {"select": select}
    for k, v in filters.items():
        params[k] = f"eq.{v}"
    rows = sbr(table, params)
    return rows[0] if rows else None

def sb_list(table: str, select: str, **filters) -> List[Dict[str,Any]]:
    params = {"select": select}
    for k, v in filters.items():
        params[k] = f"eq.{v}"
    return sbr(table, params)

# ---------- Domain helpers ----------
def _current_period(profile_id: str) -> Dict[str,Any]:
    today = datetime.date.today().isoformat()
    rows = sbr("Monthly_Financial_Record", {
        "select": "record_id,period_start,period_end",
        "profile_id": f"eq.{profile_id}",
        "period_start": f"lte.{today}",
        "period_end":   f"gte.{today}",
    })
    if rows:
        return rows[0]
    rows = sbr("Monthly_Financial_Record", {
        "select": "record_id,period_start,period_end",
        "profile_id": f"eq.{profile_id}",
        "order": "period_end.desc",
        "limit": "1",
    })
    if not rows:
        raise HTTPException(404, "No monthly record found")
    return rows[0]

# ---------- Tool implementations (REAL DB QUERIES) ----------
def get_balance(profile_id: str, user_id: str | None = None) -> Dict[str, Any]:
    # Prefer direct field from User_Profile as per your schema
    v = sb_single("User_Profile", "current_balance", profile_id=profile_id)
    if v and "current_balance" in v and v["current_balance"] is not None:
        return {"balance_sar": float(v["current_balance"]), "source": "User_Profile"}

    # Fallback: incomes - expenses in current period
    period = _current_period(profile_id)
    start, end = period["period_start"], period["period_end"]

    # Use PostgREST and=() for range filters
    incomes = sbr("Transaction", {
        "select": "amount",
        "profile_id": f"eq.{profile_id}",
        "type": "eq.income",
        "and": f"(date.gte.{start},date.lte.{end})",
    })
    expenses = sbr("Transaction", {
        "select": "amount",
        "profile_id": f"eq.{profile_id}",
        "type": "eq.expense",
        "and": f"(date.gte.{start},date.lte.{end})",
    })

    inc = sum(float(x["amount"]) for x in incomes if x.get("amount") is not None)
    exp = sum(float(x["amount"]) for x in expenses if x.get("amount") is not None)
    return {"balance_sar": round(inc - exp, 2), "source": "computed", "period": period}

def get_payday(profile_id: str, user_id: str | None = None) -> Dict[str, Any]:
    """
    Fixed_Income(income_id, name, monthly_income, payday, ..., is_primary, profile_id)
    Return the primary income's payday & amount if available.
    """
    rows = sbr("Fixed_Income", {
        "select": "income_id,name,monthly_income,payday,is_primary",
        "profile_id": f"eq.{profile_id}",
        "is_primary": "eq.true",
        "limit": "1",
    })
    if rows:
        r = rows[0]
        return {
            "next_payday": r.get("payday"),
            "amount": r.get("monthly_income"),
            "source": "Fixed_Income(primary)"
        }
    return {"next_payday": None, "source": "none"}

def get_fixed_incomes(profile_id: str, user_id: str | None = None) -> Dict[str, Any]:
    rows = sb_list(
        "Fixed_Income",
        "income_id,name,monthly_income,payday,start_time,end_time,is_primary,is_transacted,last_update",
        profile_id=profile_id,
    )
    return {"incomes": rows}

def get_fixed_expenses(profile_id: str, user_id: str | None = None) -> Dict[str, Any]:
    rows = sb_list(
        "Fixed_Expense",
        "expense_id,name,amount,due_date,is_transacted,last_update",
        profile_id=profile_id,
    )
    return {"expenses": rows}

def get_current_record(profile_id: str, user_id: str | None = None) -> Dict[str,Any]:
    period = _current_period(profile_id)
    return {"record": period}

def get_category_summary(
    profile_id: str,
    category_id: Optional[str] = None,
    user_id: Optional[str] = None
) -> Dict[str, Any]:
    """
    Uses your schema:

    Category_Summary(summary_id, total_expense, record_id, category_id)
    Monthly_Financial_Record(record_id, period_start, period_end, ..., profile_id)
    Category(category_id, name, monthly_limit, ... , profile_id)

    Returns per-category: category_id, category_name, limit, spent, remaining, percent_used
    for the *current* monthly record (by profile_id).
    """
    period = _current_period(profile_id)
    rec_id = period["record_id"]

    # 1) Pull all summaries for the active record
    params = {
        "select": "summary_id,total_expense,record_id,category_id",
        "record_id": f"eq.{rec_id}",
    }
    rows: List[Dict[str, Any]] = sbr("Category_Summary", params)

    if category_id:
        rows = [r for r in rows if r.get("category_id") == category_id]

    if not rows:
        return {"record": period, "summaries": []}

    # 2) Fetch categories for those IDs to get name + monthly_limit
    cat_ids = sorted({r["category_id"] for r in rows if r.get("category_id")})
    cats = sbr("Category", {
        "select": "category_id,name,monthly_limit",
        "category_id": f"in.({','.join(cat_ids)})",
        "profile_id": f"eq.{profile_id}",
    })
    cat_by_id = {c["category_id"]: c for c in cats}

    # 3) Merge + compute fields
    out = []
    for r in rows:
        cid = r["category_id"]
        c = cat_by_id.get(cid, {})
        limit = float(c.get("monthly_limit", 0) or 0)
        spent = float(r.get("total_expense", 0) or 0)
        remaining = max(limit - spent, 0.0)
        percent_used = 0.0 if limit <= 0 else round(100.0 * spent / limit, 2)

        out.append({
            "category_id": cid,
            "category_name": c.get("name", ""),
            "limit": round(limit, 2),
            "spent": round(spent, 2),
            "remaining": round(remaining, 2),
            "percent_used": percent_used,
        })

    return {"record": period, "summaries": out}

def suggest_savings_plan(profile_id: str, user_id: str | None = None) -> Dict[str,Any]:
    bal = get_balance(profile_id)
    payday = get_payday(profile_id)
    balance = float(bal.get("balance_sar", 0))
    suggestion = max(0, round(balance * 0.15, 2))
    return {
        "plan": f"Suggested savings: {suggestion} SAR before {payday.get('next_payday')}.",
        "inputs": {"balance": balance, "payday": payday.get("next_payday")},
    }

# --- Helper for goal transfers ---
def _signed_transfer_amount(direction: Optional[str], amount: Any) -> float:
    """
    Interpret Goal_Transfer.direction as + / - for computing saved amount.
    We don't assume exact string set, just a reasonable convention:
      - 'from_goal', 'withdraw', 'out' => negative
      - everything else (or None)      => positive
    """
    if amount is None:
        return 0.0

    value = float(amount)
    dir_norm = (direction or "").lower()

    if dir_norm in ("from_goal", "withdraw", "out"):
        return -value
    return value

def get_top_spending(
    profile_id: str,
    user_id: str | None = None,
    n: int = 3,
) -> Dict[str, Any]:
    """
    Top-N categories by total_expense for the current month.
    Reuses get_category_summary() which already respects your schema.
    """
    summary = get_category_summary(profile_id=profile_id, user_id=user_id)
    record = summary.get("record")
    summaries: List[Dict[str, Any]] = summary.get("summaries", [])

    # Keep only categories where spent > 0
    non_zero = [s for s in summaries if float(s.get("spent", 0) or 0) > 0]
    non_zero.sort(key=lambda s: float(s.get("spent", 0) or 0), reverse=True)

    # Clamp n between 1 and 10 (as per tool schema)
    n = max(1, min(n or 3, 10))
    top_n = non_zero[:n]

    return {
        "record": record,
        "top_spending": top_n,
    }

def get_weekly_summary(
    profile_id: str,
    user_id: str | None = None,
) -> Dict[str, Any]:
    """
    Daily expense/income totals for the current week using Transaction.date.
    Week starts on Monday.
    """
    today = datetime.date.today()
    week_start = today - datetime.timedelta(days=today.weekday())  # Monday
    week_end = week_start + datetime.timedelta(days=6)

    start_str = week_start.isoformat()
    end_str = week_end.isoformat()

    rows: List[Dict[str, Any]] = sbr(
        "Transaction",
        {
            "select": "date,type,amount",
            "profile_id": f"eq.{profile_id}",
            "and": f"(date.gte.{start_str},date.lte.{end_str})",
        },
    )

    # Initialize all days with zeros
    by_day: Dict[str, Dict[str, float]] = {}
    for i in range(7):
        d = (week_start + datetime.timedelta(days=i)).isoformat()
        by_day[d] = {"income": 0.0, "expense": 0.0}

    for r in rows:
        d = r.get("date")
        if not d:
            continue

        ttype = (r.get("type") or "").lower()  # 'income' or 'expense'
        amount = float(r.get("amount", 0) or 0)

        if d not in by_day:
            by_day[d] = {"income": 0.0, "expense": 0.0}

        if ttype == "income":
            by_day[d]["income"] += amount
        elif ttype == "expense":
            by_day[d]["expense"] += amount

    days = []
    for i in range(7):
        d = (week_start + datetime.timedelta(days=i)).isoformat()
        income = round(by_day[d]["income"], 2)
        expense = round(by_day[d]["expense"], 2)
        days.append(
            {
                "date": d,
                "income": income,
                "expense": expense,
                "net": round(income - expense, 2),
            }
        )

    return {
        "week_start": start_str,
        "week_end": end_str,
        "days": days,
    }

def get_goals(
    profile_id: str,
    user_id: str | None = None,
) -> Dict[str, Any]:
    """
    Return all goals for profile_id, with progress computed from Goal_Transfer.
    """
    goals: List[Dict[str, Any]] = sb_list(
        "Goal",
        "goal_id,name,target_amount,target_date,status,created_at,profile_id",
        profile_id=profile_id,
    )

    if not goals:
        return {"goals": []}

    out = []
    for g in goals:
        gid = g["goal_id"]
        target = float(g.get("target_amount", 0) or 0)

        transfers: List[Dict[str, Any]] = sb_list(
            "Goal_Transfer",
            "goal_transfer_id,direction,amount,created_at,goal_id",
            goal_id=gid,
        )

        saved = 0.0
        for t in transfers:
            saved += _signed_transfer_amount(
                t.get("direction"),
                t.get("amount"),
            )

        progress = round(saved, 2)
        remaining = max(target - progress, 0.0)
        percent = 0.0 if target <= 0 else round(100.0 * progress / target, 2)

        out.append(
            {
                "goal_id": gid,
                "name": g.get("name", ""),
                "target_amount": target,
                "target_date": g.get("target_date"),
                "status": g.get("status"),
                "created_at": g.get("created_at"),
                "progress": progress,
                "remaining": round(remaining, 2),
                "percent_complete": percent,
            }
        )

    return {"goals": out}

def simulate_purchase(
    profile_id: str,
    user_id: str | None = None,
    price: float = 0.0,
    category_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Check if a price fits the selected category and compute new balance.
    Uses get_balance() + get_category_summary().
    """
    price = float(price or 0)

    # 1) Balance impact
    bal_info = get_balance(profile_id=profile_id, user_id=user_id)
    balance_before = float(bal_info.get("balance_sar", 0))
    balance_after = round(balance_before - price, 2)
    can_afford = balance_after >= 0

    # 2) Category impact (if category_id provided)
    cat_block: Optional[Dict[str, Any]] = None
    if category_id:
        cat_info = get_category_summary(
            profile_id=profile_id,
            category_id=category_id,
            user_id=user_id,
        )
        summaries = cat_info.get("summaries", [])
        if summaries:
            cs = summaries[0]
            remaining_before = float(cs.get("remaining", 0) or 0)
            remaining_after = round(remaining_before - price, 2)
            will_overspend = remaining_after < 0

            cat_block = {
                "category_id": cs.get("category_id"),
                "category_name": cs.get("category_name"),
                "limit": float(cs.get("limit", 0) or 0),
                "spent_before": float(cs.get("spent", 0) or 0),
                "remaining_before": remaining_before,
                "remaining_after": remaining_after,
                "will_overspend": will_overspend,
            }

    return {
        "profile_id": profile_id,
        "price": price,
        "balance_before": balance_before,
        "balance_after": balance_after,
        "can_afford": can_afford,
        "category_effect": cat_block,
    }

# Map tool names to functions
NAME_TO_FUNC = {
    "get_balance": get_balance,
    "get_payday": get_payday,
    "get_fixed_incomes": get_fixed_incomes,
    "get_fixed_expenses": get_fixed_expenses,
    "get_current_record": get_current_record,
    "get_category_summary": get_category_summary,
    "get_top_spending": get_top_spending,
    "get_weekly_summary": get_weekly_summary,
    "get_goals": get_goals,
    "simulate_purchase": simulate_purchase,
    "suggest_savings_plan": suggest_savings_plan,
}

# ---------- API ----------
app = FastAPI(title="Surra Chat API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["*"], allow_headers=["*"], allow_credentials=True,
)

EXPECTED_KEY = os.getenv("BACKEND_API_KEY", "").strip()

@app.middleware("http")
async def check_key(request: Request, call_next):
    # Allow docs & health without key
    if request.url.path in ("/docs", "/openapi.json", "/health", "/"):
        return await call_next(request)

    if not EXPECTED_KEY:
        # Misconfig on server side
        raise HTTPException(500, "Server misconfig: BACKEND_API_KEY missing")

    got = request.headers.get("x-api-key")  # header names are case-insensitive
    if got != EXPECTED_KEY:
        raise HTTPException(401, "Unauthorized: invalid API key")

    return await call_next(request)

class ChatIn(BaseModel):
    text: str
    profile_id: str
    user_id: Optional[str] = None
    model: Optional[str] = None

@app.get("/")
def root():
    return {"ok": True, "service": "Surra backend", "model": FT_MODEL_ID or "gpt-3.5-turbo-0125"}

@app.get("/health")
def health():
    return {"status": "healthy"}

@app.post("/chat")
def chat(body: ChatIn):
    try:
        model = body.model or FT_MODEL_ID
        print(f"📦 /chat using model: {model}")
        r = client.chat.completions.create(
            model=model,
            messages=[
                {"role":"system","content":"You are Surra, a precise but friendly finance assistant. Use tools when needed."},
                {"role":"user","content": body.text},
            ],
            tools=OPENAI_TOOLS,
            tool_choice="auto",
        )
        msg = r.choices[0].message

        tool_msgs: List[Dict[str,Any]] = []
        traces: List[Dict[str,Any]] = []

        if msg.tool_calls:
            for call in msg.tool_calls:
                name = call.function.name
                args = json.loads(call.function.arguments or "{}")

                # 🔒 Always override IDs from body (never trust the LLM for these)
                args["profile_id"] = body.profile_id
                if body.user_id is not None:
                    args["user_id"] = body.user_id

                fn = NAME_TO_FUNC.get(name)
                result = fn(**args) if fn else {"error": f"tool {name} not implemented"}
                traces.append({"tool": name, "args": args, "result": result})

                tool_msgs.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "name": name,
                    "content": json.dumps(result, ensure_ascii=False)
                })

            r2 = client.chat.completions.create(
                model=model,
                messages=[
                    {"role":"system","content":"You are Surra, a precise but friendly finance assistant. Use tools when needed."},
                    {"role":"user","content": body.text},
                    msg,
                    *tool_msgs,
                ],
            )
            answer = r2.choices[0].message.content
        else:
            answer = msg.content

        return {
    "answer": answer,
    "tool_traces": traces,
    "model_used": model
}

    except Exception as e:
        print("=== /chat ERROR ===")
        traceback.print_exc()
        return JSONResponse(
            status_code=500,
            content={"error": str(e), "type": e.__class__.__name__},
        )

# --- Local runner: lets you do `python backend/main.py`
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=PORT, reload=True)

print("Loaded tools:", [t["function"]["name"] for t in OPENAI_TOOLS])

