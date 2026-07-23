from app.database.supabase import supabase
from app.services.ai_service import AIService


class ChatService:

    @staticmethod
    def create_conversation(user_id: str, title: str):
        response = (
            supabase.table("conversations")
            .insert({
                "user_id": user_id,
                "title": title
            })
            .execute()
        )
        return response

    @staticmethod
    def save_message(conversation_id: str, role: str, content: str):
        response = (
            supabase.table("messages")
            .insert({
                "conversation_id": conversation_id,
                "role": role,
                "content": content
            })
            .execute()
        )
        return response

    @staticmethod
    def get_messages(conversation_id: str):
        response = (
            supabase.table("messages")
            .select("*")
            .eq("conversation_id", conversation_id)
            .order("created_at")
            .execute()
        )
        return response

    @staticmethod
    def process_message(conversation_id: str, user_message: str):

        ChatService.save_message(
            conversation_id,
            "user",
            user_message
        )

        ai_response = AIService.generate_response(user_message)

        ChatService.save_message(
            conversation_id,
            "assistant",
            ai_response
        )

        return ai_response
