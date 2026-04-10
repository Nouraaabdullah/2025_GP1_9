# backend/recommendations.py

import os
import json
import math
import datetime
from typing import Any, Dict, List, Optional

import httpx
from dotenv import load_dotenv
from openai import OpenAI
from pathlib import Path
from fastapi import HTTPException

# Load backend/.env
load_dotenv(dotenv_path=Path(__file__).with_name(".env"))

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
DASHBOARD_REC_MODEL = os.getenv("DASHBOARD_REC_MODEL", "gpt-4o-mini")

if not all([OPENAI_API_KEY, SUPABASE_URL, SERVICE_KEY]):
    raise RuntimeError("Missing required env vars for dashboard recommendations")

client = OpenAI(api_key=OPENAI_API_KEY)
REST = f"{SUPABASE_URL}/rest/v1"


# =========================================================
# Shared REST helpers
# =========================================================
def sbr(path: str, params: Dict[str, str] | None = None) -> List[Dict[str, Any]]:
    with httpx.Client(timeout=25) as c:
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


def sb_single(table: str, select: str, **filters) -> Optional[Dict[str, Any]]:
    params = {"select": select}
    for k, v in filters.items():
        params[k] = f"eq.{v}"
    rows = sbr(table, params)
    return rows[0] if rows else None


def safe_float(v: Any, default: float = 0.0) -> float:
    try:
        if v is None or v == "":
            return default
        return float(v)
    except Exception:
        return default


# =========================================================
# Layer 1 — Data Fetching
# Fetch richer user context for last 9 months
# =========================================================
def fetch_user_recommendation_context(profile_id: str, months: int = 9) -> Dict[str, Any]:
    today = datetime.date.today()
    approx_start = (today.replace(day=1) - datetime.timedelta(days=32 * (months - 1))).replace(day=1)

    # 1) User profile
    profile = sb_single(
        "User_Profile",
        "profile_id,current_balance,full_name,user_id",
        profile_id=profile_id,
    ) or {}

    # 2) Last 9 months financial records
    monthly_records = sbr(
        "Monthly_Financial_Record",
        {
            "select": "record_id,period_start,period_end,total_expense,total_income,total_earning,monthly_saving,profile_id",
            "profile_id": f"eq.{profile_id}",
            "period_start": f"gte.{approx_start.isoformat()}",
            "order": "period_start.asc",
            "limit": str(months),
        },
    )

    record_ids = [r["record_id"] for r in monthly_records if r.get("record_id")]

    # 3) Categories
    categories = sbr(
        "Category",
        {
            "select": "category_id,name,monthly_limit,icon,icon_color,profile_id,is_archived",
            "profile_id": f"eq.{profile_id}",
        },
    )

    category_map = {c["category_id"]: c for c in categories if c.get("category_id")}

    # 4) Category summaries for those last 9 months
    category_summaries = []
    if record_ids:
        joined_ids = ",".join(record_ids)
        category_summaries = sbr(
            "Category_Summary",
            {
                "select": "summary_id,total_expense,record_id,category_id",
                "record_id": f"in.({joined_ids})",
            },
        )

    # 5) Fixed income
    fixed_incomes = sbr(
        "Fixed_Income",
        {
            "select": "income_id,name,monthly_income,payday,is_primary,is_transacted,start_time,end_time,last_update,profile_id",
            "profile_id": f"eq.{profile_id}",
        },
    )

    # 6) Fixed expense
    fixed_expenses = sbr(
        "Fixed_Expense",
        {
            "select": "expense_id,name,amount,due_date,is_transacted,last_update,profile_id",
            "profile_id": f"eq.{profile_id}",
        },
    )

    # 7) Goals
    goals = sbr(
        "Goal",
        {
            "select": "goal_id,name,target_amount,target_date,status,created_at,profile_id",
            "profile_id": f"eq.{profile_id}",
        },
    )

    goal_ids = [g["goal_id"] for g in goals if g.get("goal_id")]

    # 8) Goal transfers
    goal_transfers = []
    if goal_ids:
        joined_goal_ids = ",".join(goal_ids)
        goal_transfers = sbr(
            "Goal_Transfer",
            {
                "select": "goal_transfer_id,direction,amount,created_at,goal_id",
                "goal_id": f"in.({joined_goal_ids})",
            },
        )

    # 9) Recent transactions in last 9 months
    recent_transactions = sbr(
        "Transaction",
        {
            "select": "amount,date,type,category_id,profile_id",
            "profile_id": f"eq.{profile_id}",
            "date": f"gte.{approx_start.isoformat()}",
            "order": "date.asc",
        },
    )

    return {
        "profile": profile,
        "monthly_records": monthly_records,
        "categories": categories,
        "category_map": category_map,
        "category_summaries": category_summaries,
        "fixed_incomes": fixed_incomes,
        "fixed_expenses": fixed_expenses,
        "goals": goals,
        "goal_transfers": goal_transfers,
        "recent_transactions": recent_transactions,
        "months_requested": months,
        "start_date": approx_start.isoformat(),
        "end_date": today.isoformat(),
    }


# =========================================================
# Helper logic for Layer 2
# =========================================================
def signed_transfer_amount(direction: Optional[str], amount: Any) -> float:
    value = safe_float(amount, 0.0)
    direction = (direction or "").lower()

    if direction in ("unassign", "from_goal", "withdraw", "out"):
        return -value

    return value


def enrich_goals(goals: List[Dict[str, Any]], transfers: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    transfer_map: Dict[str, List[Dict[str, Any]]] = {}
    for t in transfers:
        gid = t.get("goal_id")
        if gid:
            transfer_map.setdefault(gid, []).append(t)

    enriched = []
    for g in goals:
        gid = g.get("goal_id")
        target = safe_float(g.get("target_amount"), 0.0)
        user_transfers = transfer_map.get(gid, [])

        progress = round(sum(signed_transfer_amount(t.get("direction"), t.get("amount")) for t in user_transfers), 2)
        remaining = max(target - progress, 0.0)
        percent_complete = 0.0 if target <= 0 else round((progress / target) * 100, 2)

        enriched.append({
            **g,
            "progress": progress,
            "remaining": round(remaining, 2),
            "percent_complete": percent_complete,
            "transfer_count": len(user_transfers),
        })

    return enriched


def get_latest_record(records: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not records:
        return None
    return records[-1]


def get_previous_record(records: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if len(records) < 2:
        return None
    return records[-2]


def pct_change(current: float, previous: float) -> Optional[float]:
    if previous == 0:
        return None
    return round(((current - previous) / previous) * 100.0, 2)


def trend_direction(values: List[float], tolerance: float = 0.05) -> str:
    filtered = [v for v in values if v is not None]
    if len(filtered) < 2:
        return "unknown"

    start = filtered[0]
    end = filtered[-1]

    if start == 0 and end == 0:
        return "flat"
    if start == 0 and end > 0:
        return "up"

    change_ratio = (end - start) / max(abs(start), 1e-9)

    if change_ratio > tolerance:
        return "up"
    if change_ratio < -tolerance:
        return "down"
    return "flat"


# =========================================================
# Layer 2 — Insight Signals
# =========================================================
def build_income_overview_signals(ctx: Dict[str, Any]) -> Dict[str, Any]:
    records = ctx["monthly_records"]
    latest = get_latest_record(records)

    if not latest:
        return {"enough_data": False}

    total_income = safe_float(latest.get("total_income"))
    total_earning = safe_float(latest.get("total_earning"))
    total_expense = safe_float(latest.get("total_expense"))
    current_balance = safe_float(ctx["profile"].get("current_balance"))

    total_available = total_income + total_earning
    expense_ratio = round((total_expense / total_available) * 100, 2) if total_available > 0 else None
    income_left = round(total_available - total_expense, 2)
    income_left_ratio = round((income_left / total_available) * 100, 2) if total_available > 0 else None

    balance_health = "unknown"
    if current_balance > 0 and total_expense == 0:
        balance_health = "healthy"
    elif current_balance >= 0:
        if total_available > 0 and total_expense <= total_available * 0.7:
            balance_health = "healthy"
        elif total_available > 0 and total_expense <= total_available:
            balance_health = "medium"
        else:
            balance_health = "risky"
    else:
        balance_health = "critical"

    return {
        "enough_data": True,
        "current_balance": round(current_balance, 2),
        "total_income": round(total_income, 2),
        "total_earning": round(total_earning, 2),
        "total_expense": round(total_expense, 2),
        "total_available": round(total_available, 2),
        "income_left": income_left,
        "expense_ratio_percent": expense_ratio,
        "income_left_ratio_percent": income_left_ratio,
        "balance_health": balance_health,
        "record_period_start": latest.get("period_start"),
        "record_period_end": latest.get("period_end"),
    }


def build_financial_trends_signals(ctx: Dict[str, Any]) -> Dict[str, Any]:
    records = ctx["monthly_records"]
    if len(records) < 2:
        return {"enough_data": False}

    incomes = [safe_float(r.get("total_income")) for r in records]
    earnings = [safe_float(r.get("total_earning")) for r in records]
    expenses = [safe_float(r.get("total_expense")) for r in records]
    savings = [safe_float(r.get("monthly_saving")) for r in records]

    latest = records[-1]
    previous = records[-2]

    latest_income = safe_float(latest.get("total_income"))
    latest_earning = safe_float(latest.get("total_earning"))
    latest_expense = safe_float(latest.get("total_expense"))
    latest_saving = safe_float(latest.get("monthly_saving"))

    prev_income = safe_float(previous.get("total_income"))
    prev_earning = safe_float(previous.get("total_earning"))
    prev_expense = safe_float(previous.get("total_expense"))
    prev_saving = safe_float(previous.get("monthly_saving"))

    return {
        "enough_data": True,
        "months_count": len(records),
        "income_trend": trend_direction(incomes),
        "earning_trend": trend_direction(earnings),
        "expense_trend": trend_direction(expenses),
        "saving_trend": trend_direction(savings),
        "latest_income": latest_income,
        "latest_earning": latest_earning,
        "latest_expense": latest_expense,
        "latest_saving": latest_saving,
        "income_change_percent": pct_change(latest_income, prev_income),
        "earning_change_percent": pct_change(latest_earning, prev_earning),
        "expense_change_percent": pct_change(latest_expense, prev_expense),
        "saving_change_percent": pct_change(latest_saving, prev_saving),
        "latest_period_start": latest.get("period_start"),
        "latest_period_end": latest.get("period_end"),
    }


def build_savings_over_time_signals(ctx: Dict[str, Any]) -> Dict[str, Any]:
    records = ctx["monthly_records"]
    if len(records) < 2:
        return {"enough_data": False}

    savings_values = [safe_float(r.get("monthly_saving")) for r in records]
    latest = records[-1]
    previous = records[-2]

    enriched_goals = enrich_goals(ctx["goals"], ctx["goal_transfers"])
    active_goals = [g for g in enriched_goals if (g.get("status") or "").lower() == "active"]
    close_goals = [g for g in enriched_goals if safe_float(g.get("percent_complete")) >= 75 and safe_float(g.get("percent_complete")) < 100]
    inactive_goals = [g for g in enriched_goals if g.get("transfer_count", 0) == 0]

    latest_saving = safe_float(latest.get("monthly_saving"))
    previous_saving = safe_float(previous.get("monthly_saving"))

    return {
        "enough_data": True,
        "saving_trend": trend_direction(savings_values),
        "latest_saving": latest_saving,
        "previous_saving": previous_saving,
        "saving_change_percent": pct_change(latest_saving, previous_saving),
        "active_goals_count": len(active_goals),
        "goals_close_to_completion_count": len(close_goals),
        "inactive_goals_count": len(inactive_goals),
        "top_close_goals": [
            {
                "name": g.get("name"),
                "remaining": safe_float(g.get("remaining")),
                "percent_complete": safe_float(g.get("percent_complete")),
            }
            for g in close_goals[:3]
        ],
        "latest_period_start": latest.get("period_start"),
        "latest_period_end": latest.get("period_end"),
    }


def build_category_breakdown_signals(ctx: Dict[str, Any]) -> Dict[str, Any]:
    records = ctx["monthly_records"]
    if not records:
        return {"enough_data": False}

    latest = records[-1]
    latest_record_id = latest.get("record_id")
    if not latest_record_id:
        return {"enough_data": False}

    latest_summaries = [s for s in ctx["category_summaries"] if s.get("record_id") == latest_record_id]
    if not latest_summaries:
        return {"enough_data": False}

    total_expense = round(sum(safe_float(s.get("total_expense")) for s in latest_summaries), 2)
    if total_expense <= 0:
        return {"enough_data": False}

    categories_info = []
    for s in latest_summaries:
        cid = s.get("category_id")
        cat = ctx["category_map"].get(cid, {})
        spent = round(safe_float(s.get("total_expense")), 2)
        limit_val = safe_float(cat.get("monthly_limit"), 0.0)
        share_pct = round((spent / total_expense) * 100, 2) if total_expense > 0 else None

        categories_info.append({
            "category_id": cid,
            "name": cat.get("name"),
            "spent": spent,
            "limit": limit_val if limit_val > 0 else None,
            "share_percent": share_pct,
            "remaining": round(limit_val - spent, 2) if limit_val > 0 else None,
            "near_limit": (limit_val > 0 and spent >= 0.8 * limit_val),
            "over_limit": (limit_val > 0 and spent > limit_val),
        })

    categories_info.sort(key=lambda x: x["spent"], reverse=True)
    top = categories_info[0] if categories_info else None

    near_limit = [c for c in categories_info if c["near_limit"]]
    over_limit = [c for c in categories_info if c["over_limit"]]

    concentration_level = "low"
    if top and safe_float(top.get("share_percent")) >= 50:
        concentration_level = "high"
    elif top and safe_float(top.get("share_percent")) >= 35:
        concentration_level = "medium"

    return {
        "enough_data": True,
        "total_expense": total_expense,
        "top_category": top,
        "top_3_categories": categories_info[:3],
        "near_limit_categories": [
            {"name": c["name"], "spent": c["spent"], "limit": c["limit"]}
            for c in near_limit[:3]
        ],
        "over_limit_categories": [
            {"name": c["name"], "spent": c["spent"], "limit": c["limit"]}
            for c in over_limit[:3]
        ],
        "category_count": len(categories_info),
        "concentration_level": concentration_level,
        "latest_period_start": latest.get("period_start"),
        "latest_period_end": latest.get("period_end"),
    }


# =========================================================
# Section context builder
# =========================================================
def build_section_context(profile_id: str, section: str, months: int = 9) -> Dict[str, Any]:
    ctx = fetch_user_recommendation_context(profile_id=profile_id, months=months)

    if section == "income_overview":
        signals = build_income_overview_signals(ctx)
    elif section == "financial_trends":
        signals = build_financial_trends_signals(ctx)
    elif section == "savings_over_time":
        signals = build_savings_over_time_signals(ctx)
    elif section == "category_breakdown":
        signals = build_category_breakdown_signals(ctx)
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported section: {section}")

    return {
        "section": section,
        "months_used": months,
        "raw_context": ctx,
        "signals": signals,
    }


# =========================================================
# Layer 3 — GPT wording
# =========================================================
def generate_dashboard_recommendation(profile_id: str, section: str, period: str = "monthly", months: int = 9) -> Dict[str, Any]:
    built = build_section_context(profile_id=profile_id, section=section, months=months)
    signals = built["signals"]

    if not signals.get("enough_data"):
        return {
            "ok": True,
            "section": section,
            "recommendation": None,
            "message": "We need more data to generate insights for you.",
            "signals": signals,
        }

    system_prompt = """
You are Surra's dashboard recommendation engine.

Your task:
Generate exactly ONE short financial recommendation for the requested dashboard section.

Rules:
- Keep it short: maximum 24 words.
- Make it practical and personalized.
- It must match the dashboard section exactly.
- Focus only on the provided section signals.
- Do not invent any number or fact.
- Do not mention JSON, models, tools, database, backend, or signals.
- Prefer actionable and meaningful advice over simply repeating labels.
- The tone should be supportive, clear, and natural.

Return valid JSON only in this exact format:
{
  "recommendation": "string",
  "message": null
}
"""

    user_prompt = f"""
Section: {section}
Period: {period}
Months analyzed: {months}

Signals:
{json.dumps(signals, ensure_ascii=False)}
"""

    response = client.chat.completions.create(
        model=DASHBOARD_REC_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        response_format={"type": "json_object"},
        temperature=0.3,
    )

    content = response.choices[0].message.content
    parsed = json.loads(content)

    recommendation = parsed.get("recommendation")
    if not isinstance(recommendation, str) or not recommendation.strip():
        return {
            "ok": True,
            "section": section,
            "recommendation": None,
            "message": "We need more data to generate insights for you.",
            "signals": signals,
        }

    return {
        "ok": True,
        "section": section,
        "recommendation": recommendation.strip(),
        "message": parsed.get("message"),
        "signals": signals,
    }