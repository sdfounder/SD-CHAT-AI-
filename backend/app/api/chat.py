from fastapi import APIRouter
from pydantic import BaseModel

from app.services.chat_service import ChatService

router = APIRouter()


class ConversationRequest(BaseModel):
    user_id: str
    title: str
class MessageRequest(BaseModel):
    conversation_id: str
    message: str

@router.post("/conversation")
def create_conversation(data: ConversationRequest):
    result = ChatService.create_conversation(
        user_id=data.user_id,
        title=data.title
    )

    return result.data

@router.post("/message")
def send_message(data: MessageRequest):

    response = ChatService.process_message(
        conversation_id=data.conversation_id,
        user_message=data.message
    )

    return {
        "response": response
    }
