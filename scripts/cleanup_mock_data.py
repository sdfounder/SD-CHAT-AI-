import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

from app.database.connection import db_manager

REAL_ADMIN_ID = "a16a6379-d44a-4f02-9183-99fa6de9d4a7"
REAL_ADMIN_EMAIL = "sekoudiaby433@gmail.com"

def run_cleanup():
    print("=== DÉBUT DU NETTOYAGE DES MOCKS ET DONNÉES FICTIVES ===")
    with db_manager.connect() as conn:
        # 1. Mise à jour de admin_credentials pour pointer sur REAL_ADMIN_ID
        print("1. Mise à jour admin_credentials...")
        conn.run(
            """
            UPDATE public.admin_credentials
            SET id = :real_id
            WHERE email = :email
            """,
            real_id=REAL_ADMIN_ID,
            email=REAL_ADMIN_EMAIL,
        )

        # 2. Nettoyage des conversations de test et messages associés
        print("2. Nettoyage des conversations et messages de test...")
        # Suppression cascades
        conn.run("DELETE FROM public.chat_attachment_blobs WHERE attachment_id IN (SELECT id FROM public.chat_attachments WHERE user_id != :real_id)", real_id=REAL_ADMIN_ID)
        conn.run("DELETE FROM public.chat_attachments WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)
        conn.run("DELETE FROM public.shared_conversations WHERE conversation_id IN (SELECT id FROM public.chat_conversations WHERE user_id != :real_id)", real_id=REAL_ADMIN_ID)
        conn.run("DELETE FROM public.chat_messages WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)
        conn.run("DELETE FROM public.chat_conversations WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)

        # 3. Nettoyage des abonnements de test
        print("3. Nettoyage des abonnements fictifs...")
        conn.run("DELETE FROM public.subscriptions WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)
        # S'assurer que le compte réel a bien son abonnement
        conn.run(
            """
            INSERT INTO public.subscriptions (id, user_id, plan_id, status, created_at, updated_at)
            VALUES (gen_random_uuid(), :real_id, 'free', 'active', NOW(), NOW())
            ON CONFLICT (id) DO NOTHING
            """,
            real_id=REAL_ADMIN_ID,
        )

        # 4. Nettoyage user_feedback fictifs
        print("4. Nettoyage des retours utilisateurs fictifs...")
        conn.run("DELETE FROM public.user_feedback WHERE user_id LIKE 'fb-user-%' OR (user_id != :real_id AND user_id IS NOT NULL)", real_id=REAL_ADMIN_ID)

        # 5. Nettoyage métriques IA fictives
        print("5. Nettoyage des métriques IA fictives...")
        conn.run("DELETE FROM public.ai_request_metrics WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)

        # 6. Nettoyage des tables d'usage de test
        print("6. Nettoyage de l'usage utilisateur...")
        conn.run("DELETE FROM public.chat_user_usage WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)
        conn.run("DELETE FROM public.user_usage WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)
        conn.run("DELETE FROM public.notifications WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)
        conn.run("DELETE FROM public.devices WHERE user_id != :real_id", real_id=REAL_ADMIN_ID)

        # 7. Suppression du profil doublon et des profils mockés
        print("7. Nettoyage des profils fictifs...")
        # D'abord dissocier les clés étrangères éventuelles sur le profil doublon 6e88...
        OLD_DOUBLON = "6e887b6b-3339-4297-89e0-d3ec2658a83a"
        conn.run("DELETE FROM public.profiles WHERE id = :old_id", old_id=OLD_DOUBLON)

        # Supprimer tous les profils qui ne sont pas le vrai profil
        conn.run(
            """
            DELETE FROM public.profiles
            WHERE id != :real_id
            """,
            real_id=REAL_ADMIN_ID,
        )

        # 8. S'assurer que le profil réel a le rôle admin, tier premium, et statut actif
        print("8. Consolidation du profil réel administrateur...")
        conn.run(
            """
            UPDATE public.profiles
            SET role = 'admin',
                tier = 'premium',
                full_name = 'Sekou Diaby',
                email = :email,
                is_suspended = false,
                status = 'active',
                last_active_at = NOW(),
                updated_at = NOW()
            WHERE id = :real_id
            """,
            real_id=REAL_ADMIN_ID,
            email=REAL_ADMIN_EMAIL,
        )

        # 9. Audit de vérification
        print("\n=== VÉRIFICATION DES COMPTAGES APRÈS NETTOYAGE ===")
        total_p = conn.run("SELECT COUNT(*) FROM public.profiles")[0][0]
        total_s = conn.run("SELECT COUNT(*) FROM public.subscriptions")[0][0]
        total_c = conn.run("SELECT COUNT(*) FROM public.chat_conversations")[0][0]
        total_m = conn.run("SELECT COUNT(*) FROM public.chat_messages")[0][0]
        total_f = conn.run("SELECT COUNT(*) FROM public.user_feedback")[0][0]
        total_ai = conn.run("SELECT COUNT(*) FROM public.ai_request_metrics")[0][0]
        profiles_list = conn.run("SELECT id, email, role, tier, full_name FROM public.profiles")

        print(f"Total profiles: {total_p} (Attendu: 1)")
        print(f"Total subscriptions: {total_s} (Attendu: 1)")
        print(f"Total conversations: {total_c} (Attendu: 0)")
        print(f"Total messages: {total_m} (Attendu: 0)")
        print(f"Total feedback: {total_f} (Attendu: 0)")
        print(f"Total ai_metrics: {total_ai} (Attendu: 0)")
        print("Profil conservé :", profiles_list)

if __name__ == "__main__":
    run_cleanup()
