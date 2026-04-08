import os
from typing import Optional
from supabase import create_client, Client


SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise ValueError("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment variables.")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


class NotificationService:
    @staticmethod
    def create_notification(
        profile_id: str,
        title: str,
        body: str,
        notification_type: str,
        route: Optional[str] = None,
    ):
        payload = {
            "profile_id": profile_id,
            "title": title,
            "body": body,
            "type": notification_type,
            "route": route,
            "is_read": False,
        }

        response = supabase.table("Notification").insert(payload).execute()
        return response

    @staticmethod
    def create_budget_alert(
        profile_id: str,
        category_name: str,
        spent: float,
        limit: float,
    ):
        return NotificationService.create_notification(
            profile_id=profile_id,
            title="Budget Alert",
            body=f"You exceeded your {category_name} budget. Spent: {spent:.2f} SAR, Limit: {limit:.2f} SAR.",
            notification_type="budget_alert",
            route="/budget",
        )

    @staticmethod
    def create_goal_reached(
        profile_id: str,
        goal_name: str,
    ):
        return NotificationService.create_notification(
            profile_id=profile_id,
            title="Goal Reached",
            body=f"Congratulations! You reached your goal: {goal_name}.",
            notification_type="goal_reached",
            route="/goals",
        )

    @staticmethod
    def create_reminder_notification(
        profile_id: str,
        reminder_title: str,
    ):
        return NotificationService.create_notification(
            profile_id=profile_id,
            title="Reminder",
            body=f"Don't forget: {reminder_title}",
            notification_type="reminder",
            route="/reminders",
        )