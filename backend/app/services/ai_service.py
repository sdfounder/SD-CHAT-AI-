class AIService:
    """
    Première version du cerveau de SD CHAT AI.
    Pour l'instant, il renvoie une réponse fixe.
    Plus tard, il utilisera un véritable modèle d'IA.
    """

    @staticmethod
    def generate_response(user_message: str) -> str:
        user_message = user_message.strip()

        if not user_message:
            return "Je n'ai reçu aucun message."

        return (
            "Bonjour, je suis SD CHAT AI et je suis votre IA personnelle. "
            "Je suis encore en cours de développement, mais chaque jour j'apprends de nouvelles fonctionnalités."
        )
