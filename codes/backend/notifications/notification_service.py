'''2025_GP1_9/codes/backend/notifications/notification_service.py'''
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
    ):
        payload = {
            "profile_id": profile_id,
            "title": title,
            "body": body,
            "type": notification_type,
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
            body=f"You exceeded your {category_name} budget.",
            notification_type="budget_alert",
        )

    @staticmethod
    def create_goal_completed(
        profile_id: str,
        goal_name: str,
    ):
        return NotificationService.create_notification(
            profile_id=profile_id,
            title="Goal Completed",
            body=f"Congratulations! You completed your goal: {goal_name}.",
            notification_type="goal_completed",
        )

    @staticmethod
    def create_goal_reminder(
        profile_id: str,
        goal_name: str,
    ):
        return NotificationService.create_notification(
            profile_id=profile_id,
            title="Goal Reminder",
            body=f"Reminder: your goal {goal_name} is due tomorrow.",
            notification_type="goal_reminder",
        )

    @staticmethod
    def create_negative_balance_alert(
        profile_id: str,
    ):
        return NotificationService.create_notification(
            profile_id=profile_id,
            title="Negative Balance Alert",
            body="Your balance is negative.",
            notification_type="negative_balance",
        )