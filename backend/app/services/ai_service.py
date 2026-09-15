class AIService:
    """
    Service IA de SD CHAT AI
    Version 0.2 : gestion du contexte conversationnel.
    """

    @staticmethod
    def generate_response(user_message: str, conversation_history: list) -> str:

        if not user_message.strip():
            return "Je n'ai reçu aucun message."

        history_count = len(conversation_history)

        last_role = "aucun"
        if history_count > 0:
            last_role = conversation_history[-1].get("role", "inconnu")

        return (
            f"Bonjour, je suis SD CHAT AI.\n\n"
            f"Tu m'as envoyé : '{user_message}'.\n"
            f"La conversation contient actuellement {history_count} message(s).\n"
            f"Le dernier message enregistré est de : {last_role}.\n\n"
            f"Mon véritable moteur d'intelligence artificielle sera bientôt connecté."
        )
