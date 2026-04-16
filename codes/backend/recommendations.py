# backend/recommendations.py

import os
import json
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


def parse_date(value: Any) -> Optional[datetime.date]:
    if not value:
        return None
    try:
        return datetime.date.fromisoformat(str(value)[:10])
    except Exception:
        return None


# =========================================================
# Data fetching
# =========================================================
def fetch_user_recommendation_context(profile_id: str, months: int = 9) -> Dict[str, Any]:
    today = datetime.date.today()
    approx_start = (today.replace(day=1) - datetime.timedelta(days=32 * (months - 1))).replace(day=1)

    profile = sb_single(
        "User_Profile",
        "profile_id,current_balance,full_name,user_id",
        profile_id=profile_id,
    ) or {}

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

    categories = sbr(
        "Category",
        {
            "select": "category_id,name,monthly_limit,icon,icon_color,profile_id,is_archived",
            "profile_id": f"eq.{profile_id}",
        },
    )
    active_categories = [c for c in categories if not c.get("is_archived", False)]
    category_map = {c["category_id"]: c for c in active_categories if c.get("category_id")}

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

    fixed_incomes = sbr(
        "Fixed_Income",
        {
            "select": "income_id,name,monthly_income,payday,is_primary,is_transacted,start_time,end_time,last_update,profile_id",
            "profile_id": f"eq.{profile_id}",
        },
    )

    fixed_expenses = sbr(
        "Fixed_Expense",
        {
            "select": "expense_id,name,amount,due_date,is_transacted,start_time,end_time,last_update,profile_id,category_id",
            "profile_id": f"eq.{profile_id}",
        },
    )

    goals = sbr(
        "Goal",
        {
            "select": "goal_id,name,target_amount,target_date,status,created_at,profile_id",
            "profile_id": f"eq.{profile_id}",
        },
    )

    goal_ids = [g["goal_id"] for g in goals if g.get("goal_id")]

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
        "categories": active_categories,
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
# Helpers
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


def pct_change(current: float, previous: float) -> Optional[float]:
    if previous == 0:
        return None
    return round(((current - previous) / previous) * 100.0, 2)


def days_until_payday(payday_raw: Any, today: datetime.date) -> Optional[int]:
    if payday_raw in (None, "", 0):
        return None

    s = str(payday_raw)

    try:
        payday_date = datetime.date.fromisoformat(s[:10])
        delta = (payday_date - today).days
        return delta if delta >= 0 else None
    except Exception:
        pass

    try:
        payday_day = int(float(s))
        payday_day = max(1, min(payday_day, 31))

        year = today.year
        month = today.month

        while True:
            try:
                candidate = datetime.date(year, month, payday_day)
            except ValueError:
                if month == 12:
                    next_month = datetime.date(year + 1, 1, 1)
                else:
                    next_month = datetime.date(year, month + 1, 1)
                candidate = next_month - datetime.timedelta(days=1)

            if candidate >= today:
                return (candidate - today).days

            if month == 12:
                year += 1
                month = 1
            else:
                month += 1

    except Exception:
        return None


def days_until_due(due_raw: Any, today: datetime.date) -> Optional[int]:
    if due_raw in (None, "", 0):
        return None

    s = str(due_raw)

    try:
        due_date = datetime.date.fromisoformat(s[:10])
        delta = (due_date - today).days
        return delta if delta >= 0 else None
    except Exception:
        pass

    try:
        due_day = int(float(s))
        due_day = max(1, min(due_day, 31))

        year = today.year
        month = today.month

        while True:
            try:
                candidate = datetime.date(year, month, due_day)
            except ValueError:
                if month == 12:
                    next_month = datetime.date(year + 1, 1, 1)
                else:
                    next_month = datetime.date(year, month + 1, 1)
                candidate = next_month - datetime.timedelta(days=1)

            if candidate >= today:
                return (candidate - today).days

            if month == 12:
                year += 1
                month = 1
            else:
                month += 1

    except Exception:
        return None


# =========================================================
# Combined daily recommendation signals
# =========================================================
def build_daily_recommendation_signals(ctx: Dict[str, Any]) -> Dict[str, Any]:
    today = datetime.date.today()

    profile = ctx["profile"]
    monthly_records = ctx["monthly_records"]
    category_map = ctx["category_map"]
    category_summaries = ctx["category_summaries"]
    fixed_incomes = ctx["fixed_incomes"]
    fixed_expenses = ctx["fixed_expenses"]
    recent_transactions = ctx["recent_transactions"]

    latest_record = monthly_records[-1] if monthly_records else None
    previous_record = monthly_records[-2] if len(monthly_records) >= 2 else None

    current_balance = round(safe_float(profile.get("current_balance")), 2)

    latest_income = round(safe_float(latest_record.get("total_income")) if latest_record else 0.0, 2)
    latest_earning = round(safe_float(latest_record.get("total_earning")) if latest_record else 0.0, 2)
    latest_expense = round(safe_float(latest_record.get("total_expense")) if latest_record else 0.0, 2)
    latest_saving = round(safe_float(latest_record.get("monthly_saving")) if latest_record else 0.0, 2)

    previous_income = round(safe_float(previous_record.get("total_income")) if previous_record else 0.0, 2)
    previous_expense = round(safe_float(previous_record.get("total_expense")) if previous_record else 0.0, 2)
    previous_saving = round(safe_float(previous_record.get("monthly_saving")) if previous_record else 0.0, 2)

    total_available_latest = round(latest_income + latest_earning, 2)
    expense_ratio_percent = round((latest_expense / total_available_latest) * 100, 2) if total_available_latest > 0 else None

    # Paydays
    primary_income = next((x for x in fixed_incomes if x.get("is_primary") is True), None)
    fallback_income = fixed_incomes[0] if fixed_incomes else None
    selected_income = primary_income or fallback_income

    next_payday_days = None
    next_payday_amount = None
    next_payday_name = None
    if selected_income:
        next_payday_days = days_until_payday(selected_income.get("payday"), today)
        next_payday_amount = round(safe_float(selected_income.get("monthly_income")), 2)
        next_payday_name = selected_income.get("name")

    total_fixed_income = round(sum(safe_float(i.get("monthly_income")) for i in fixed_incomes), 2)

    # Fixed expenses — enrich with days_until_due
    fixed_expenses_enriched = []
    for e in fixed_expenses:
        days = days_until_due(e.get("due_date"), today)
        amount = round(safe_float(e.get("amount")), 2)
        fixed_expenses_enriched.append({
            "name": e.get("name"),
            "amount": amount,
            "days_until_due": days,  # None if no due date or already passed
        })

    # Bills due in various windows — sum totals only, no individual names
    bills_due_7d = [e for e in fixed_expenses_enriched if e["days_until_due"] is not None and e["days_until_due"] <= 7]
    bills_due_14d = [e for e in fixed_expenses_enriched if e["days_until_due"] is not None and e["days_until_due"] <= 14]
    bills_due_30d = [e for e in fixed_expenses_enriched if e["days_until_due"] is not None and e["days_until_due"] <= 30]

    total_due_soon_7d = round(sum(x["amount"] for x in bills_due_7d), 2)
    total_due_soon_14d = round(sum(x["amount"] for x in bills_due_14d), 2)
    total_due_soon_30d = round(sum(x["amount"] for x in bills_due_30d), 2)
    total_fixed_expenses = round(sum(safe_float(e.get("amount")) for e in fixed_expenses), 2)

    # -------------------------------------------------------
    # PRE-COMPUTED PRIORITY SIGNALS
    # These tell the LLM what actually matters, removing
    # any guesswork about significance or currency.
    # -------------------------------------------------------

    # Is the total bills-due amount significant relative to balance?
    # "Significant" = total due in 14d is >= 10% of balance
    bills_14d_significant = (
        total_due_soon_14d > 0
        and current_balance > 0
        and (total_due_soon_14d / current_balance) >= 0.10
    )
    # Is the user at risk of not covering upcoming bills before payday?
    bills_before_payday_risk = False
    bills_before_payday_total = 0.0
    if next_payday_days is not None:
        bills_before_payday = [
            e for e in fixed_expenses_enriched
            if e["days_until_due"] is not None and e["days_until_due"] <= next_payday_days
        ]
        bills_before_payday_total = round(sum(x["amount"] for x in bills_before_payday), 2)
        bills_before_payday_risk = bills_before_payday_total > current_balance

    # Overspending signals
    over_limit_categories = []
    near_limit_categories = []
    top_spending_categories = []

    if latest_record and latest_record.get("record_id"):
        latest_record_id = latest_record["record_id"]
        latest_summaries = [s for s in category_summaries if s.get("record_id") == latest_record_id]

        categories_info = []
        for s in latest_summaries:
            cid = s.get("category_id")
            cat = category_map.get(cid, {})
            spent = round(safe_float(s.get("total_expense")), 2)
            limit_val = safe_float(cat.get("monthly_limit"), 0.0)

            entry = {
                "name": cat.get("name"),
                "spent": spent,
                "limit": round(limit_val, 2) if limit_val > 0 else None,
                "remaining": round(limit_val - spent, 2) if limit_val > 0 else None,
                "near_limit": (limit_val > 0 and spent >= 0.8 * limit_val),
                "over_limit": (limit_val > 0 and spent > limit_val),
            }
            categories_info.append(entry)

        categories_info.sort(key=lambda x: x["spent"], reverse=True)
        top_spending_categories = categories_info[:3]
        near_limit_categories = [c for c in categories_info if c["near_limit"]][:3]
        over_limit_categories = [c for c in categories_info if c["over_limit"]][:3]

    # Goals
    enriched_goals = enrich_goals(ctx["goals"], ctx["goal_transfers"])
    active_goals = [
        g for g in enriched_goals
        if (g.get("status") or "").lower() == "active"
        and safe_float(g.get("percent_complete")) < 100
    ]
    active_goals.sort(key=lambda g: (safe_float(g.get("remaining")), parse_date(g.get("target_date")) or datetime.date.max))

    top_goal = active_goals[0] if active_goals else None
    goals_close_to_completion = [
        {
            "name": g.get("name"),
            "remaining": safe_float(g.get("remaining")),
            "percent_complete": safe_float(g.get("percent_complete")),
            "target_date": g.get("target_date"),
        }
        for g in active_goals
        if 75 <= safe_float(g.get("percent_complete")) < 100
    ][:3]

    # Activity
    transaction_count = len(recent_transactions)
    expense_tx_count = sum(1 for t in recent_transactions if str(t.get("type", "")).lower() == "expense")
    earning_tx_count = sum(1 for t in recent_transactions if str(t.get("type", "")).lower() == "earning")
    has_any_expense_history = expense_tx_count > 0 or latest_expense > 0
    has_any_income_data = (latest_income > 0) or (total_fixed_income > 0) or bool(fixed_incomes)
    is_new_user_like = has_any_income_data and not has_any_expense_history and len(monthly_records) <= 1

    # Cash pressure
    cash_pressure = "low"
    if current_balance < 0:
        cash_pressure = "critical"
    elif total_due_soon_7d > 0 and current_balance < total_due_soon_7d:
        cash_pressure = "high"
    elif total_due_soon_14d > 0 and current_balance < total_due_soon_14d:
        cash_pressure = "medium"

    # -------------------------------------------------------
    # RECOMMENDATION PRIORITY LABEL
    # Pre-determined priority so the LLM focuses on the right thing.
    # The LLM must follow this priority and use the exact SAR values.
    # -------------------------------------------------------
    if cash_pressure in ("critical", "high"):
        recommendation_priority = "cash_shortage_risk"
    elif bills_before_payday_risk:
        recommendation_priority = "bills_exceed_balance_before_payday"
    elif over_limit_categories:
        recommendation_priority = "category_over_limit"
    elif bills_14d_significant:
        recommendation_priority = "significant_bills_upcoming"
    elif near_limit_categories:
        recommendation_priority = "category_near_limit"
    elif expense_ratio_percent is not None and expense_ratio_percent > 80:
        recommendation_priority = "high_expense_ratio"
    elif top_goal:
        recommendation_priority = "goal_progress"
    elif latest_saving > 0:
        recommendation_priority = "positive_saving"
    else:
        recommendation_priority = "general_overview"

    return {
        "today": today.isoformat(),
        "currency": "SAR",  # ALWAYS SAR — never use $ or any other currency
        "months_analyzed": len(monthly_records),
        "months_requested": ctx["months_requested"],

        "profile": {
            "full_name": profile.get("full_name"),
            "current_balance_SAR": current_balance,
        },

        "current_snapshot": {
            "latest_period_start": latest_record.get("period_start") if latest_record else None,
            "latest_period_end": latest_record.get("period_end") if latest_record else None,
            "latest_income_SAR": latest_income,
            "latest_earning_SAR": latest_earning,
            "latest_expense_SAR": latest_expense,
            "latest_saving_SAR": latest_saving,
            "total_available_SAR": total_available_latest,
            "expense_ratio_percent": expense_ratio_percent,
        },

        "changes_vs_previous": {
            "income_change_percent": pct_change(latest_income, previous_income) if previous_record else None,
            "expense_change_percent": pct_change(latest_expense, previous_expense) if previous_record else None,
            "saving_change_percent": pct_change(latest_saving, previous_saving) if previous_record else None,
        },

        "income_and_payday": {
            "has_income_data": has_any_income_data,
            "total_fixed_income_SAR": total_fixed_income,
            "next_payday_days": next_payday_days,
            "next_payday_amount_SAR": next_payday_amount,
            "income_sources_count": len(fixed_incomes),
        },

        "recurring_expenses": {
            # IMPORTANT: All amounts are in SAR. Do NOT convert or relabel.
            "total_fixed_expenses_SAR": total_fixed_expenses,
            # Use these totals in recommendations — do NOT name individual small bills.
            "total_due_next_7_days_SAR": total_due_soon_7d,
            "total_due_next_14_days_SAR": total_due_soon_14d,
            "total_due_next_30_days_SAR": total_due_soon_30d,
            "bills_count_due_14d": len(bills_due_14d),
            # bills_before_payday_total: total bills due before next payday
            "bills_before_payday_total_SAR": bills_before_payday_total,
            "bills_before_payday_risk": bills_before_payday_risk,
        },

        "goals": {
            "goals_count": len(enriched_goals),
            "active_goals_count": len(active_goals),
            "top_goal": {
                "name": top_goal.get("name"),
                "remaining_SAR": safe_float(top_goal.get("remaining")),
                "percent_complete": safe_float(top_goal.get("percent_complete")),
                "target_date": top_goal.get("target_date"),
            } if top_goal else None,
            "goals_close_to_completion": goals_close_to_completion,
        },

        "budgeting": {
            "categories_count": len(ctx["categories"]),
            "top_spending_categories": top_spending_categories,
            "near_limit_categories": near_limit_categories,
            "over_limit_categories": over_limit_categories,
        },

        "activity": {
            "transaction_count_last_months": transaction_count,
            "expense_transaction_count": expense_tx_count,
            "earning_transaction_count": earning_tx_count,
            "has_any_expense_history": has_any_expense_history,
            "is_new_user_like": is_new_user_like,
        },

        "summary_flags": {
            "cash_pressure": cash_pressure,
            "has_goals": len(enriched_goals) > 0,
            "has_fixed_expenses": len(fixed_expenses) > 0,
            "has_category_limits": any(safe_float(c.get("monthly_limit")) > 0 for c in ctx["categories"]),
            "bills_14d_significant": bills_14d_significant,
        },

        # The LLM MUST use this to decide what to focus on.
        "recommendation_priority": recommendation_priority,
    }


# =========================================================
# LLM recommendation
# =========================================================
def generate_daily_dashboard_recommendation(profile_id: str, months: int = 9) -> Dict[str, Any]:
    ctx = fetch_user_recommendation_context(profile_id=profile_id, months=months)
    signals = build_daily_recommendation_signals(ctx)

    system_prompt = """
You are Surra's dashboard recommendation engine.

Your task:
Generate exactly ONE short financial overview recommendation for the user.

━━━━━━━━━━━━━━━━━━━━━━━━━
STRICT RULES — NEVER BREAK THESE
━━━━━━━━━━━━━━━━━━━━━━━━━
1. CURRENCY: ALWAYS use "SAR". NEVER use "$", "USD", "SR", or any other currency symbol.
2. LENGTH: Maximum 26 words. Be concise.
3. NUMBERS: Only use exact SAR values from the signals. NEVER invent or estimate numbers.
4. INDIVIDUAL BILL NAMES: Do NOT name specific individual recurring expenses (e.g. "Netflix", "new test") unless total_due is 0 and there is only one bill. Focus on totals and impact.
5. PRIORITY: You MUST follow the `recommendation_priority` field in signals. That field tells you exactly what to address. Do not override it.
6. NO TECH TALK: Never mention JSON, signals, database, backend, models, or missing data.
7. POSITIVE TONE: Be helpful and supportive, not alarmist.

━━━━━━━━━━━━━━━━━━━━━━━━━
HOW TO USE recommendation_priority
━━━━━━━━━━━━━━━━━━━━━━━━━
- "cash_shortage_risk": Warn that balance may not cover upcoming bills. Use current_balance_SAR and total_due values.
- "bills_exceed_balance_before_payday": Warn that recurring bills before payday exceed the balance. Use bills_before_payday_total_SAR and next_payday_days.
- "category_over_limit": Mention that a spending category has exceeded its limit this month. Use category name and amounts.
- "significant_bills_upcoming": Mention the TOTAL upcoming bills in SAR (not individual names) and when they are due. Use total_due_next_14_days_SAR or total_due_next_30_days_SAR.
- "category_near_limit": Mention that a category is approaching its limit and suggest monitoring spending.
- "high_expense_ratio": Mention that expenses are a high percentage of income this month.
- "goal_progress": Encourage goal progress. Use top_goal name and remaining_SAR.
- "positive_saving": Celebrate healthy saving and suggest maintaining or increasing it.
- "general_overview": Give a brief positive overview of their financial health.

━━━━━━━━━━━━━━━━━━━━━━━━━
EXAMPLES OF GOOD RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ "You have 250 SAR in recurring bills due in the next 14 days. Your balance is healthy — stay on track."
✅ "Your Entertainment category is nearing its monthly limit. Consider slowing discretionary spending this week."
✅ "Great month — you saved 1,200 SAR. Keep it up and consider adding to your goals."
✅ "You have 2 bills totaling 250 SAR due before your next payday. Your balance covers them comfortably."

━━━━━━━━━━━━━━━━━━━━━━━━━
EXAMPLES OF BAD RECOMMENDATIONS (NEVER DO THESE)
━━━━━━━━━━━━━━━━━━━━━━━━━
❌ "Prepare for upcoming Netflix bills totaling $140..." — wrong currency, names individual bill, wrong amount
❌ "Your balance of $14,482..." — wrong currency symbol
❌ Any number not found in the signals

Return valid JSON only in this exact format:
{
  "recommendation": "string",
  "message": null
}
"""

    user_prompt = f"""
Generate one daily dashboard recommendation for this user.

The `recommendation_priority` field tells you what to focus on. Follow it strictly.
All monetary values in the signals are in SAR. Use SAR in your recommendation.

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
        temperature=0.2,
    )

    content = response.choices[0].message.content
    parsed = json.loads(content)

    recommendation = parsed.get("recommendation")
    if not isinstance(recommendation, str) or not recommendation.strip():
        recommendation = "Review your upcoming bills, budget limits, and saving goals today to keep your spending aligned with your plan."

    # Post-process: ensure no dollar signs sneak through
    recommendation = recommendation.replace("$", "SAR ").replace("USD", "SAR").replace(" SAR  ", " SAR ")

    return {
        "ok": True,
        "recommendation": recommendation.strip(),
        "message": None,
        "generated_on": datetime.date.today().isoformat(),
        "signals": signals,
    }