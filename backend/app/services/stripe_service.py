import uuid
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional

import stripe
from fastapi import HTTPException, status

from app.core.config import settings
from app.database.connection import db_manager
from app.repositories.chat_repository import ChatRepository

logger = logging.getLogger(__name__)

# Clé API Stripe officielle
stripe.api_key = settings.stripe_secret_key

# Identifiants du produit et tarif officiel créés sur Stripe
DEFAULT_PREMIUM_PRICE_ID = "price_1UGRP9JkgRUEINU8rsFR8zBZ"
DEFAULT_PRODUCT_ID = "prod_VGzNAlwBagoHap"


class StripeService:
    """
    Service officiel de gestion des paiements et abonnements Stripe pour SD CHAT AI.
    - Aucun stockage de coordonnées bancaires ou données sensibles en base de données.
    - Synchronisation automatique et bidirectionnelle avec Supabase SD-DEV.
    - Séparation stricte environnement Test vs Production.
    """

    @staticmethod
    def get_or_create_customer(user_id: str, email: Optional[str] = None, name: Optional[str] = None) -> str:
        """
        Récupère l'identifiant Stripe Customer associé à l'utilisateur, ou en crée un nouveau.
        """
        ChatRepository.ensure_user_profile(user_id, email=email, full_name=name)

        # 1. Vérifier si un stripe_customer_id est déjà enregistré pour cet utilisateur
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT stripe_customer_id
                FROM public.subscriptions
                WHERE user_id = :uid AND stripe_customer_id IS NOT NULL
                LIMIT 1
                """,
                uid=user_id
            )
            if rows and rows[0][0]:
                customer_id = rows[0][0]
                try:
                    # Vérifier existence côté Stripe
                    stripe.Customer.retrieve(customer_id)
                    return customer_id
                except Exception as e:
                    logger.warning("Client Stripe %s non trouvable, re-création: %s", customer_id, e)

        # 2. Créer un nouveau client Stripe
        customer_email = email or f"{user_id}@sd-chat.ai"
        customer_name = name or "Utilisateur SD CHAT AI"

        customer = stripe.Customer.create(
            email=customer_email,
            name=customer_name,
            metadata={
                "user_id": user_id,
                "app": "SD CHAT AI",
                "creator": "Sekou Diaby",
                "environment": settings.environment,
            }
        )

        customer_id = customer.id
        logger.info("Nouveau client Stripe créé: %s pour user %s", customer_id, user_id)
        return customer_id

    @staticmethod
    def create_checkout_session(
        user_id: str,
        email: Optional[str] = None,
        name: Optional[str] = None,
        price_id: Optional[str] = None,
        success_url: Optional[str] = None,
        cancel_url: Optional[str] = None,
    ) -> Dict[str, str]:
        """
        Génère une session Stripe Checkout officielle en mode abonnement (subscription).
        """
        customer_id = StripeService.get_or_create_customer(user_id, email=email, name=name)
        target_price_id = price_id or DEFAULT_PREMIUM_PRICE_ID

        base_success = success_url or "https://sd-chat.ai/billing/success?session_id={CHECKOUT_SESSION_ID}"
        base_cancel = cancel_url or "https://sd-chat.ai/billing/cancel"

        try:
            session = stripe.checkout.Session.create(
                customer=customer_id,
                client_reference_id=user_id,
                mode="subscription",
                payment_method_types=["card"],
                line_items=[
                    {
                        "price": target_price_id,
                        "quantity": 1,
                    }
                ],
                success_url=base_success,
                cancel_url=base_cancel,
                metadata={
                    "user_id": user_id,
                    "app": "SD CHAT AI",
                    "plan": "premium",
                },
                subscription_data={
                    "metadata": {
                        "user_id": user_id,
                        "app": "SD CHAT AI",
                        "plan": "premium",
                    }
                },
                allow_promotion_codes=True,
            )

            logger.info("Session Stripe Checkout créée: %s pour user %s", session.id, user_id)
            return {
                "checkout_url": session.url,
                "session_id": session.id,
            }
        except stripe.StripeError as e:
            logger.error("Erreur Stripe lors de la création de la session Checkout: %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Erreur Stripe: {e.user_message or str(e)}"
            )

    @staticmethod
    def create_portal_session(user_id: str, return_url: Optional[str] = None) -> str:
        """
        Génère une session Stripe Customer Portal pour gérer l'abonnement en toute conformité.
        """
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT stripe_customer_id
                FROM public.subscriptions
                WHERE user_id = :uid AND stripe_customer_id IS NOT NULL
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                uid=user_id
            )

        if not rows or not rows[0][0]:
            # Créer un customer si nécessaire
            customer_id = StripeService.get_or_create_customer(user_id)
        else:
            customer_id = rows[0][0]

        target_return_url = return_url or "https://sd-chat.ai/billing/return"

        try:
            portal_session = stripe.billing_portal.Session.create(
                customer=customer_id,
                return_url=target_return_url,
            )
            return portal_session.url
        except stripe.StripeError as e:
            logger.error("Erreur Stripe Customer Portal: %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Impossible d'ouvrir le portail client: {e.user_message or str(e)}"
            )

    @staticmethod
    def get_user_subscription(user_id: str) -> Dict[str, Any]:
        """
        Récupère l'état complet de l'abonnement d'un utilisateur depuis Supabase.
        """
        with db_manager.connect() as conn:
            rows = conn.run(
                """
                SELECT id, user_id, plan_id, status, stripe_customer_id, stripe_subscription_id,
                       current_period_start, current_period_end, cancel_at_period_end
                FROM public.subscriptions
                WHERE user_id = :uid
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                uid=user_id
            )

        if not rows:
            return {
                "user_id": user_id,
                "plan_id": "free",
                "status": "free",
                "is_premium": False,
                "stripe_customer_id": None,
                "stripe_subscription_id": None,
                "current_period_start": None,
                "current_period_end": None,
                "cancel_at_period_end": False,
            }

        sub = rows[0]
        sub_status = sub[3]
        period_end = sub[7]

        # Vérification expiration
        is_active = sub_status == "active"
        if period_end:
            now = datetime.now(timezone.utc)
            if period_end.tzinfo is None:
                period_end = period_end.replace(tzinfo=timezone.utc)
            if period_end <= now:
                is_active = False

        return {
            "user_id": sub[1],
            "plan_id": sub[2],
            "status": sub_status,
            "is_premium": is_active and sub[2] in ("premium", "pro"),
            "stripe_customer_id": sub[4],
            "stripe_subscription_id": sub[5],
            "current_period_start": sub[6],
            "current_period_end": sub[7],
            "cancel_at_period_end": bool(sub[8]),
        }

    @staticmethod
    def sync_subscription_from_stripe(subscription_data: Any, explicit_user_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Synchronise un abonnement Stripe avec Supabase :
        1. Résout le user_id SD CHAT AI.
        2. Met à jour la table public.subscriptions.
        3. Met à jour public.profiles.tier ('premium' ou 'free').
        """
        # Convertir en dictionnaire si objet stripe
        if hasattr(subscription_data, "to_dict"):
            sub_dict = subscription_data.to_dict()
        elif isinstance(subscription_data, dict):
            sub_dict = subscription_data
        else:
            sub_dict = dict(subscription_data)

        stripe_sub_id = sub_dict.get("id")
        stripe_cust_id = sub_dict.get("customer")
        sub_status = sub_dict.get("status", "unknown")
        cancel_at_period_end = sub_dict.get("cancel_at_period_end", False)

        # Extraction des dates
        period_start_ts = sub_dict.get("current_period_start")
        period_end_ts = sub_dict.get("current_period_end")

        period_start = datetime.fromtimestamp(period_start_ts, tz=timezone.utc) if period_start_ts else datetime.now(timezone.utc)
        period_end = datetime.fromtimestamp(period_end_ts, tz=timezone.utc) if period_end_ts else None

        # Résolution du user_id
        user_id = explicit_user_id
        if not user_id and "metadata" in sub_dict and sub_dict["metadata"]:
            user_id = sub_dict["metadata"].get("user_id")

        if not user_id and stripe_cust_id:
            # Recherche par stripe_customer_id
            with db_manager.connect() as conn:
                rows = conn.run(
                    "SELECT user_id FROM public.subscriptions WHERE stripe_customer_id = :cid LIMIT 1",
                    cid=stripe_cust_id
                )
                if rows:
                    user_id = rows[0][0]

        if not user_id:
            logger.error("Impossible de résoudre user_id pour l'abonnement Stripe %s", stripe_sub_id)
            return {"error": "user_id non identifié"}

        ChatRepository.ensure_user_profile(user_id)

        plan_id = "premium"
        is_active = sub_status == "active"
        if period_end:
            now = datetime.now(timezone.utc)
            if period_end <= now:
                is_active = False

        # 1. Mise à jour ou insertion dans public.subscriptions
        with db_manager.connect() as conn:
            existing = conn.run(
                """
                SELECT id FROM public.subscriptions
                WHERE stripe_subscription_id = :sid OR user_id = :uid
                LIMIT 1
                """,
                sid=stripe_sub_id,
                uid=user_id
            )

            if existing:
                sub_uuid = existing[0][0]
                conn.run(
                    """
                    UPDATE public.subscriptions
                    SET plan_id = :plan,
                        status = :status,
                        stripe_customer_id = :cid,
                        stripe_subscription_id = :sid,
                        current_period_start = :start,
                        current_period_end = :end,
                        cancel_at_period_end = :cancel,
                        updated_at = NOW()
                    WHERE id = :id
                    """,
                    plan=plan_id,
                    status=sub_status,
                    cid=stripe_cust_id,
                    sid=stripe_sub_id,
                    start=period_start,
                    end=period_end,
                    cancel=cancel_at_period_end,
                    id=sub_uuid
                )
            else:
                conn.run(
                    """
                    INSERT INTO public.subscriptions (
                        id, user_id, plan_id, status, stripe_customer_id, stripe_subscription_id,
                        current_period_start, current_period_end, cancel_at_period_end, created_at, updated_at
                    )
                    VALUES (
                        :id, :uid, :plan, :status, :cid, :sid, :start, :end, :cancel, NOW(), NOW()
                    )
                    """,
                    id=str(uuid.uuid4()),
                    uid=user_id,
                    plan=plan_id,
                    status=sub_status,
                    cid=stripe_cust_id,
                    sid=stripe_sub_id,
                    start=period_start,
                    end=period_end,
                    cancel=cancel_at_period_end
                )

            # 2. Mise à jour immédiate du profil utilisateur
            new_tier = "premium" if is_active else "free"
            conn.run(
                """
                UPDATE public.profiles
                SET tier = :tier, updated_at = NOW()
                WHERE id = :uid
                """,
                tier=new_tier,
                uid=user_id
            )

        logger.info(
            "Abonnement Stripe %s synchronisé pour user %s: status=%s, tier=%s",
            stripe_sub_id, user_id, sub_status, new_tier
        )
        return {
            "user_id": user_id,
            "status": sub_status,
            "tier": new_tier,
            "stripe_subscription_id": stripe_sub_id,
        }

    @staticmethod
    def handle_webhook_event(payload: bytes, sig_header: Optional[str]) -> Dict[str, Any]:
        """
        Traite un événement webhook Stripe avec vérification de signature.
        """
        event = None

        # Vérification cryptographique si webhook secret configuré
        webhook_secret = settings.stripe_webhook_secret
        if webhook_secret and not webhook_secret.startswith("whsec_placeholder") and sig_header:
            try:
                event = stripe.Webhook.construct_event(
                    payload, sig_header, webhook_secret
                )
            except Exception as e:
                logger.error("Signature de webhook Stripe invalide: %s", str(e))
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Signature webhook invalide: {str(e)}"
                )
        elif settings.environment == "production":
            logger.error("Webhook Stripe rejeté : signature ou secret manquant en production")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Signature de webhook Stripe obligatoire en environnement de production."
            )
        else:
            # Mode test / développement tolérant pour tests unitaires hors ligne
            try:
                import json
                event_data = json.loads(payload.decode("utf-8"))
                event = stripe.Event.construct_from(event_data, stripe.api_key)
            except Exception as e:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Payload JSON invalide: {str(e)}"
                )

        event_type = event["type"]
        data_object = event["data"]["object"]
        logger.info("Webhook Stripe reçu: %s", event_type)

        if event_type == "checkout.session.completed":
            session = data_object
            user_id = session.get("client_reference_id") or (session.get("metadata") or {}).get("user_id")
            subscription_id = session.get("subscription")

            if subscription_id:
                try:
                    stripe_sub = stripe.Subscription.retrieve(subscription_id)
                    StripeService.sync_subscription_from_stripe(stripe_sub, explicit_user_id=user_id)
                except Exception as e:
                    logger.error("Erreur récupération abonnement depuis Checkout: %s", e)

        elif event_type in ("customer.subscription.created", "customer.subscription.updated", "customer.subscription.deleted"):
            StripeService.sync_subscription_from_stripe(data_object)

        elif event_type == "invoice.payment_succeeded":
            sub_id = data_object.get("subscription")
            if sub_id:
                try:
                    stripe_sub = stripe.Subscription.retrieve(sub_id)
                    StripeService.sync_subscription_from_stripe(stripe_sub)
                except Exception as e:
                    logger.warning("Invoice sync error: %s", e)

        elif event_type == "invoice.payment_failed":
            sub_id = data_object.get("subscription")
            customer_id = data_object.get("customer")
            logger.warning("Paiement échoué pour subscription %s, customer %s", sub_id, customer_id)
            if sub_id:
                with db_manager.connect() as conn:
                    conn.run(
                        """
                        UPDATE public.subscriptions
                        SET status = 'past_due', updated_at = NOW()
                        WHERE stripe_subscription_id = :sid
                        """,
                        sid=sub_id
                    )

        return {"received": True, "event_type": event_type}
