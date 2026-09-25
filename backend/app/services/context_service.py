import logging
from typing import List, Dict, Any, Optional
from app.repositories.chat_repository import ChatRepository
from app.ai.base_provider import BaseLLMProvider

logger = logging.getLogger(__name__)

# Paramètres de dimensionnement du contexte
MAX_RECENT_MESSAGES_WINDOW = 6  # 3 échanges complets (user + assistant) gardés verbatim
MAX_CONTEXT_TOKEN_BUDGET = 2500  # Budget token maximal pour l'historique
SUMMARY_TRIGGER_THRESHOLD = 12   # Seuil de déclenchement du résumé incrémental

# Flag pour future mission Mémoire Utilisateur (désactivé par défaut)
FEATURE_USER_MEMORY_ENABLED = False


class ContextService:
    """
    Gestionnaire intelligent du contexte conversationnel pour SD CHAT AI.
    - Assure l'isolation stricte entre conversations et utilisateurs.
    - Maintient une fenêtre glissante des messages récents.
    - Effectue un résumé condensé (Rolling Context Summary) des échanges lointains.
    - Intègre les métadonnées des pièces jointes sans surcoût.
    """

    @staticmethod
    def _format_attachment_metadata(attachments: List[Dict[str, Any]]) -> str:
        """Produit une chaîne descriptive compacte des métadonnées de pièces jointes."""
        if not attachments:
            return ""
        items = []
        for a in attachments:
            fname = a.get("file_name", "fichier")
            ftype = a.get("file_type", "document")
            size_bytes = a.get("file_size_bytes", 0)
            if size_bytes < 1024:
                size_str = f"{size_bytes} o"
            elif size_bytes < 1024 * 1024:
                size_str = f"{size_bytes // 1024} Ko"
            else:
                size_str = f"{size_bytes / (1024 * 1024):.1f} Mo"
            items.append(f'"{fname}" ({ftype}, {size_str})')
        return f"[Pièce(s) jointe(s) fournie(s) par l'utilisateur : {', '.join(items)}]"

    @staticmethod
    def _format_single_message(msg: Dict[str, Any]) -> Dict[str, str]:
        """Formate un message de la BD pour Gemini en injectant les métadonnées de pièces jointes."""
        role = msg.get("role", "user")
        content = msg.get("content", "")
        attachments = msg.get("attachments", [])

        if role == "user" and attachments:
            meta_str = ContextService._format_attachment_metadata(attachments)
            if content.strip():
                formatted_content = f"{content}\n\n{meta_str}"
            else:
                formatted_content = meta_str
        else:
            formatted_content = content

        return {
            "role": role,
            "content": formatted_content,
        }

    @staticmethod
    async def _generate_summary_for_messages(
        messages: List[Dict[str, Any]],
        existing_summary: Optional[str],
        ai_provider: BaseLLMProvider,
    ) -> Optional[str]:
        """Génère un résumé concis des messages anciens via le provider IA."""
        if not messages:
            return existing_summary

        dialogue_text = []
        for m in messages:
            r = "Utilisateur" if m["role"] == "user" else "Assistant"
            c = m.get("content", "").replace("\n", " ").strip()
            if c:
                dialogue_text.append(f"{r}: {c[:250]}")

        formatted_dialogue = "\n".join(dialogue_text)

        summary_instruction = (
            "Tu es le module de synthèse mémorielle de SD CHAT AI. "
            "Résume très brièvement les informations factuelles, décisions, questions clés et "
            "consignes données dans les échanges ci-dessous. Sois précis et concis (3 à 5 phrases). "
            "Ne perds aucun détail important (noms, choix techniques, préférences exprimées)."
        )

        prompt_parts = []
        if existing_summary:
            prompt_parts.append(f"Résumé précédent :\n{existing_summary}\n")
        prompt_parts.append(f"Nouveaux échanges à intégrer :\n{formatted_dialogue}\n")
        prompt_parts.append("Synthèse consolidée :")

        try:
            summary = await ai_provider.generate(
                messages=[{"role": "user", "content": "\n".join(prompt_parts)}],
                system_instruction=summary_instruction,
                temperature=0.3,
                max_tokens=300,
            )
            return summary.strip() if summary else existing_summary
        except Exception as e:
            logger.warning("Erreur lors de la génération du résumé de contexte: %s", str(e))
            return existing_summary

    @staticmethod
    async def prepare_context_messages(
        conversation_id: str,
        user_id: str,
        ai_provider: BaseLLMProvider,
        max_messages_limit: int = 50,
        conv: Optional[Dict[str, Any]] = None,
    ) -> List[Dict[str, str]]:
        """
        Construit l'historique conversationnel optimisé et sécurisé :
        1. Charge les messages ordonnés chronologiquement (vérification stricte user_id).
        2. Si <= MAX_RECENT_MESSAGES_WINDOW : renvoie l'intégralité verbatim.
        3. Si > MAX_RECENT_MESSAGES_WINDOW : compresse l'historique ancien en résumé et
           conserve les messages récents intégraux.
        """
        # 1. Vérifier la conversation et ses métadonnées (réutilisation si déjà chargée)
        if conv is None:
            conv = ChatRepository.get_conversation(conversation_id, user_id)
        if not conv:
            return []

        existing_summary = conv.get("context_summary")
        summary_until_id = conv.get("summary_until_message_id")

        # 2. Charger les messages récents (limités à max_messages_limit pour éviter un fetch géant)
        all_messages = ChatRepository.get_messages(conversation_id, user_id, limit=max_messages_limit)
        total_count = len(all_messages)

        if total_count <= MAX_RECENT_MESSAGES_WINDOW:
            # Conversation courte : injecter directement tous les messages
            return [ContextService._format_single_message(m) for m in all_messages]

        # 3. Conversation longue : découpage fenêtre glissante
        split_idx = total_count - MAX_RECENT_MESSAGES_WINDOW
        older_messages = all_messages[:split_idx]
        recent_messages = all_messages[split_idx:]

        last_older_id = older_messages[-1]["id"] if older_messages else None

        # 4. Vérifier s'il faut régénérer ou actualiser le résumé
        needs_new_summary = False
        if not existing_summary and len(older_messages) >= 2:
            needs_new_summary = True
        elif summary_until_id != last_older_id and len(older_messages) >= 4:
            needs_new_summary = True

        current_summary = existing_summary
        if needs_new_summary and last_older_id:
            try:
                new_sum = await ContextService._generate_summary_for_messages(
                    messages=older_messages,
                    existing_summary=existing_summary,
                    ai_provider=ai_provider,
                )
                if new_sum:
                    current_summary = new_sum
                    ChatRepository.update_context_summary(
                        conversation_id=conversation_id,
                        user_id=user_id,
                        context_summary=new_sum,
                        summary_until_message_id=last_older_id,
                    )
            except Exception as ex:
                logger.debug("Mise à jour résumé de contexte: %s", ex)

        # 5. Assemblage du contexte final
        final_context: List[Dict[str, str]] = []

        # Si un résumé existe, l'injecter comme premier contexte mémoriel
        if current_summary:
            summary_context_text = (
                f"[Mémoire de contexte de cette conversation (échanges précédents)] :\n{current_summary}"
            )
            final_context.append({
                "role": "user",
                "content": summary_context_text,
            })
            final_context.append({
                "role": "assistant",
                "content": "J'ai bien en mémoire le contexte des échanges précédents de cette discussion. Je continue avec précision.",
            })

        # Ajouter ensuite la fenêtre glissante des messages récents intégraux
        for msg in recent_messages:
            final_context.append(ContextService._format_single_message(msg))

        return final_context

    @staticmethod
    def get_user_memories(user_id: str) -> List[Dict[str, Any]]:
        """
        Architecture prête pour la future mémoire utilisateur inter-conversations.
        Désactivée par défaut tant que la mission Mémoire Utilisateur n'est pas activée.
        """
        if not FEATURE_USER_MEMORY_ENABLED:
            return []
        # Prêt pour interrogation de public.user_memories
        return []
