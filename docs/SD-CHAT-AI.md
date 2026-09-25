# SD CHAT AI — DOCUMENT MAÎTRE & SOURCE DE VÉRITÉ (V1)

**Version :** 1.0.0 (Production Stable)  
**Organisation :** SD Studios Digital / Écosystème SD  
**Créateur & Fondateur :** Sekou Diaby  
**Slogan :** « SD — Build the Future with AI »  
**Statut :** V1 FINALISÉE, TESTÉE ET SÉCURISÉE — BASE DE RÉFÉRENCE OFFICIELLE  
**Dernière révision :** Septembre 2026  
**Source de Vérité :** `docs/SD-CHAT-AI.md`

---

# SD CHAT AI — ÉTAT DE RÉFÉRENCE V1

> [!IMPORTANT]
> **BASE DE RÉFÉRENCE OFFICIELLE DU PROJET :**  
> Cette version 1.0.0 constitue la **base de référence immuable** pour toutes les futures évolutions et mises à jour de l'application **SD CHAT AI**.  
> 
> **RÈGLES D'OR POUR TOUT AGENT OU DÉVELOPPEUR INTERVENANT SUR CE PROJET :**
> 1. **Partir systématiquement de l'existant** : Ne jamais reconstruire l'application depuis zéro, ne pas supprimer les acquis fonctionnels des Missions 1 à 16.
> 2. **Développement incrémental strict** : Toute nouvelle fonctionnalité doit être intégrée progressivement et modulairement sans casser l'architecture établie.
> 3. **Intégrité de l'infrastructure Supabase (SD-DEV)** : Ne **JAMAIS** créer un nouveau projet Supabase sans autorisation explicite du créateur. Ne jamais supprimer de tables ou de fonctions existantes.
> 4. **Zéro simulation / Zéro Mock** : Aucun mock, aucune fausse donnée (*fake data*), aucun serveur simulé. Tout fonctionne sur les véritables briques : FastAPI, Supabase SD-DEV, Google Gemini et Stripe.
> 5. **Validation systématique des tests** : Lancer systématiquement les vérifications (`pytest` côté backend, `flutter analyze` et `flutter test` côté mobile) avant et après chaque modification.
> 6. **Préservation de l'identité visuelle** : Respecter scrupuleusement le thème souverain *Aura Obsidian & Amber-Platinum* et l'icône personnalisée exclusive.
> 7. **Modèle de travail Antigravity** : Utiliser **Gemini 3.8 Flash** comme modèle par défaut pour les futures missions d'assistance au codage.
> 8. **Évolutivité IA** : Le moteur est conçu pour permettre de brancher un futur modèle propriétaire SD sans restructurer le backend ni le frontend.

---

## 1. Vue d'Ensemble & Vision

**SD CHAT AI** est l'application conversationnelle intelligente d'élite de l'écosystème **SD — Studio Digital**. Elle combine :
- Une **application mobile Android** développée avec **Flutter 3.x / Dart**, ultra-fluide, ergonomique et responsive, parée du thème *Aura Obsidian & Amber-Platinum*.
- Un **backend haute performance** en **Python 3.11 / FastAPI**, asynchrone, sécurisé et scalé pour le streaming en temps réel Server-Sent Events (SSE).
- Le moteur d'intelligence artificielle **Google Gemini** (`gemini-3.6-flash`), confiné au backend et piloté par streaming natif SSE avec retry automatique en cas de surcharge.
- Une infrastructure de données robuste et unifiée sur **Supabase SD-DEV** (PostgreSQL avec RLS renforcé, Authentification Google, Storage privé).
- Une monétisation par abonnement avec **Stripe** (Checkout Sessions officielles et Webhooks sécurisés).
- Un **Dashboard Admin Web** intégré (`/admin`) offrant supervision en temps réel, analytics de consommation IA, gestion des utilisateurs et audit logs.

---

## 2. Architecture Technique Globale

```
┌──────────────────────────────────────────────────────────────────┐
│                   SD CHAT AI - MOBILE (Flutter)                  │
│  - Thème Aura Obsidian & Amber-Platinum  - Audio STT (Dictée)    │
│  - SSE Micro-batching 40ms               - Attachments Image/TXT │
│  - Supabase Google Auth Native           - Stripe Checkout Web   │
└────────────────────────────────┬─────────────────────────────────┘
                                 │ HTTPS / SSE Stream (JWT Bearer)
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                   BACKEND FASTAPI (Python 3.11)                  │
│  - Routeur v1 (/chat, /conversations, /attachments, /billing...) │
│  - Rate Limiter glissant                 - OWASP Security Headers│
│  - Anti-IDOR & Validation stricte        - Supervision & Logs    │
└──────────────┬──────────────────┬─────────────────┬──────────────┘
               │                  │                 │
               ▼                  ▼                 ▼
┌─────────────────────────┐┌──────────────┐┌───────────────────────┐
│     SUPABASE SD-DEV     ││GOOGLE GEMINI ││      STRIPE API       │
│  - Auth Google (Users)  ││- v1beta SSE  ││- Checkout Sessions    │
│  - PostgreSQL Pooler SSL││- Flash 3.6   ││- Webhooks signés      │
│  - RLS 100% des tables  ││- Retry 503   ││- Customer Portal      │
│  - Buckets Privés       ││- Prompt Guard││- Prod & Test Mode     │
└─────────────────────────┘└──────────────┘└───────────────────────┘
```

---

## 3. Authentification & Sécurité (Indépendant de SD Account)

### 3.1 Google Authentication Native
- Authentification Google directe et autonome intégrée via le SDK Supabase Flutter (`supabase.auth.signInWithOAuth(OAuthProvider.google)`).
- Redirection sécurisée via Deep Link Android : `com.sd.chat://login-callback`.
- Aucune dépendance de login croisé envers SD Account : SD CHAT AI dispose de sa propre session persistante locale.

### 3.2 Sécurité JWT & Autorisations
- Chaque requête vers le backend transmet le token JWT Supabase (`Authorization: Bearer <token>`).
- Le backend valide les signatures via les clés publiques JWKS Supabase avec algorithmes asymétriques stricts (`ES256`, `RS256`).
- Extraction de l'UID utilisateur (`sub`) pour garantir l'isolation multi-tenant absolue.

### 3.3 Row Level Security (RLS) PostgreSQL & Isolation Multi-Tenant
- RLS activé sur 100% des tables dans Supabase SD-DEV :
  - `chat_conversations` : Lecture, écriture, suppression restreintes à `auth.uid() = user_id`.
  - `chat_messages` : Restreint à l'utilisateur de la conversation parente.
  - `chat_attachments` & `chat_attachment_blobs` : Accès et téléchargement isolés au propriétaire.
  - `user_memories` : Mémoire contextuelle réservée au profil de l'utilisateur.
  - `admin_audit_logs`, `system_error_logs`, `ai_request_metrics` : Protégés, réservés aux administrateurs ou au `service_role`.
- **Prévention IDOR** : Lors de tout téléversement ou streaming, le backend vérifie explicitement l'appartenance de la `conversation_id` avant traitement.

### 3.4 Confinement des Secrets & Variables d'Environnement
- **Zéro clé dans Flutter** : Aucune clé Gemini, aucun secret Stripe, aucun mot de passe de base n'est inclus dans le code source Dart.
- **En-tête Gemini sécurisé** : La clé `GEMINI_API_KEY` est transmise via l'en-tête HTTP `x-goog-api-key` et non dans l'URL.
- **Git & Dépôt propres** : `.gitignore` configuré pour exclure tous les fichiers `.env*`, `key.properties`, et tous les keystores `*.jks`/`*.keystore`.

---

## 4. Moteur IA & Streaming Temps Réel

### 4.1 Fournisseur Google Gemini (`GeminiProvider`)
- Modèle de production : `gemini-3.6-flash` (haute vélocité, latence réduite, optimisé pour les interactions mobiles).
- Communication via l'API REST v1beta officielle (`streamGenerateContent?alt=sse`).
- Injection automatique de consignes système rigoureuses (identité SD, neutralisation d'injections de prompt).
- **Résilience avancée** : Boucle de réessai automatique (3 tentatives avec backoff exponentiel) en cas de code HTTP 503 (haute demande) ou 429 (rate limit).
- **Fermeture garantie des sockets** : Nettoyage systématique via `finally: await response.aclose()`.

### 4.2 Streaming Server-Sent Events (SSE)
- Endpoint : `POST /api/v1/chat/stream`.
- Format d'événement standardisé :
  ```json
  data: {"token": "...", "done": false, "conversation_id": "..."}
  ```
- **Micro-Batching Flutter (40 ms)** : Regroupement des tokens entrants côté mobile pour réduire la cadence de rebuild de 120/s à 25/s max, diminuant drastiquement la consommation CPU et la surchauffe de la batterie.
- **Bouton Stop / Interruption** : `ChatStreamHandle.cancel()` ferme la connexion client et arrête la réception sans corrompre l'historique en base.

### 4.3 Extensibilité Architecturale vers un Modèle Propriétaire SD
- Architecture basée sur l'interface abstraite `BaseLLMProvider` (`app/ai/base_provider.py`).
- Prête à accueillir un futur moteur propriétaire SD (ex: `SDLLMProvider`) sans impacter les contrôleurs ni le frontend Flutter.

---

## 5. Conversations, Mémoire Contextuelle & Pièces Jointes

### 5.1 Gestion des Conversations & Messages
- CRUD complet : Création, renommage, épinglage, archivage et suppression définitive.
- Pagination et historique consultables via le Drawer latéral moderne avec sélecteur d'onglets (Actives / Archives).
- Anti-doublons lors des réessais réseau : Le message d'erreur est nettoyé proprement avant relance.

### 5.2 Mémoire Contextuelle
- Système hybride :
  - Historique verbatim des derniers échanges (contexte conversationnel immédiat).
  - Résumé glissant pour les longues conversations afin de respecter la fenêtre de tokens.
  - Table `user_memories` pour la conservation des préférences clés de l'utilisateur.

### 5.3 Dictée Vocale Android
- Intégration du package natif `speech_to_text`.
- Microphone interactif avec pulsation lumineuse ambrée dans la barre de saisie.
- Le texte transcrit s'insère directement dans le champ de saisie pour relecture ou modification manuelle avant envoi.

### 5.4 Pièces Jointes & Supabase Storage
- Formats pris en charge :
  - Images : JPEG, PNG, WebP, GIF (jusqu'à 10 Mo).
  - Documents texte : `.txt`, `.md`, `.csv`, `.log` (jusqu'à 10 Mo).
- Stockage résilient hybride :
  - Bucket privé Supabase Storage `chat-attachments`.
  - Table de secours `chat_attachment_blobs` (BYTEA PostgreSQL) pour garantir la disponibilité.
- Mise en cache HTTP : En-tête `Cache-Control: private, max-age=86400, immutable` évitant les téléchargements superflus.
- Visualisation : Zoom/pan plein écran pour les images (`InteractiveViewer`), modal BottomSheet avec police à chasse fixe pour les fichiers texte.

---

## 6. Monétisation Stripe, Quotas & Entitlements

### 6.1 Formules & Limites de Quotas
- **Formule Free (Gratuite)** :
  - 15 messages IA par jour.
  - 3 pièces jointes par jour.
  - Réinitialisation quotidienne à minuit UTC.
- **Formule Premium (Abonnement)** :
  - 500 messages IA par jour.
  - 50 pièces jointes par jour.
  - Accès prioritaire et traitement sans file d'attente.

### 6.2 Parcours Stripe Officiel (Test Mode Sécurisé)
- **Produit Stripe** : `prod_VGzNAlwBagoHap` (*SD CHAT AI Premium*).
- **Tarif Stripe** : `price_1UGRP9JkgRUEINU8rsFR8zBZ` (19,99 € / mois).
- Endpoints dédiés :
  - `POST /api/v1/billing/checkout` : Génère la Checkout Session officielle.
  - `POST /api/v1/billing/portal` : Redirige vers le Customer Portal Stripe pour modifier la CB ou résilier.
  - `GET /api/v1/billing/subscription` : Retourne l'état de l'abonnement et date d'expiration.
  - `POST /api/v1/billing/webhook` : Écouteur sécurisé avec vérification cryptographique de signature.
- Synchronisation automatique avec la table `public.subscriptions` et mise à jour dynamique du statut `premium` / `free`.

---

## 7. Console d'Administration Web & Supervision (`https://sd-chat-admin.web.app`)

- **Hébergement Officiel Cloud** : Déployée sur Firebase Hosting sous l'URL publique courte :
  👉 **`https://sd-chat-admin.web.app`** (Site dédié `sd-chat-admin` du projet Firebase `sd-ai-5f643`, préservant intact SD-MEDIA).
- **Cycle Dynamique d'Initialisation (Inscription Initiale vs Connexion Stricte)** :
  - **Tant qu'aucun administrateur officiel n'est enregistré (`has_admin = false`)** : Le dashboard s'ouvre en mode **« Inscription Initiale de l'Administrateur »** avec badge dédié. Il autorise l'inscription via **Google Authentification** (Supabase OAuth) OU via **Email / Mot de passe**.
  - **Règle officielle du Premier Administrateur** : Le tout premier compte inscrit (Google ou Email) est automatiquement et définitivement désigné Administrateur en chef (`role = 'admin'`, formule `premium`).
  - **Dès que l'administrateur est enregistré (`has_admin = true`)** : L'inscription est définitivement close. La console bascule automatiquement en mode **« Connexion Administrateur »** uniquement. Tout formulaire ou bouton d'inscription disparaît. Toute tentative d'accès par un autre compte est rejetée avec une erreur `HTTP 403 Forbidden`.
- **Accès API Direct** : Accessible également sur le backend FastAPI via la route `/admin`.
- **Fonctionnalités administratives** :
  - KPI temps réel (utilisateurs inscrits, actifs 24h/7j, messages, tokens consommés, MRR).
  - Gestion des utilisateurs (recherche, quotas du jour, suspension/réactivation en 1 clic, ajustement manuel de formule).
  - Invalidation instantanée en mémoire du cache de statut/quota utilisateur lors de modifications administratives.
  - Gestion et suivi des abonnements Stripe réels.
  - Configuration dynamique des quotas globaux sans redémarrage.
  - Supervision des erreurs système et des interruptions de streaming.
  - Piste d'audit inviolable (`admin_audit_logs`).
  - **Graphiques d'usage interactifs (Chart.js)** : Volume de messages, coût estimé, latence moyenne/TTFT, répartition des pièces jointes, filtres par période (`24h`, `7d`, `30d`, `90d`, `all`).
  - Confidentialité : Masquage systématique des emails des utilisateurs et anonymisation stricte.

---

## 8. Configuration Android & Binaire Release

### 8.1 Métadonnées & Identifiants
- **Application ID** : `com.sd.chat.sd_chat_ai`
- **Nom de l'application** : `SD CHAT AI`
- **Version Name** : `1.0.0`
- **Version Code** : `1`
- **Min SDK** : 24 (Android 7.0 Nougat)
- **Target SDK / Compile SDK** : 34 / 36

### 8.2 Permissions Minimales Auditées
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```
*(Aucune permission superflue : aucune caméra indiscrète, aucun SMS, aucune localisation).*

### 8.3 Icône Personnalisée Officielle
- Identité exclusive *Aura Obsidian & Amber-Platinum* (fusion cerveau IA + bulle de dialogue, or-ambre `#F59E0B`, chrome platine `#E2E8F0`, fond sombre `#0B0F19`).
- Configuration Adaptive Icon complète :
  - `mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
  - `mobile/android/app/src/main/res/values/colors.xml`
  - Déclinaisons raster : `mdpi` (48px), `hdpi` (72px), `xhdpi` (96px), `xxhdpi` (144px), `xxxhdpi` (192px).
  - Master haute résolution 512×512 dans `mobile/assets/icon-512.png`.

### 8.4 Signature Release & Keystore
- Keystore : `mobile/android/app/upload-keystore.jks` (ignoré par Git).
- Propriétés de signature : `mobile/android/key.properties` (ignoré par Git).
- Alias : `sd-chat-upload` (RSA 2048, validité 10 000 jours).
- DN : `CN=Sekou Diaby, OU=SD Ecosystem, O=SD, L=Paris, ST=IDF, C=FR`.
- Sauvegarde sécurisée des identifiants : `~/.sd_chat_keystore_secret.txt` (permissions `chmod 600`).
- **Artefacts générés et vérifiés** :
  - **APK Release signé** : `mobile/build/app/outputs/flutter-apk/app-release.apk` (56,5 Mo - Signature APK v2 : OK).
  - **AAB Release signé** : `mobile/build/app/outputs/bundle/release/app-release.aab` (55,2 Mo - Jarsigner Play App Signing : OK).

---

## 9. Arborescence du Projet

```
SD-CHAT-AI/
├── backend/
│   ├── app/
│   │   ├── ai/                  # Providers IA (GeminiProvider, BaseLLMProvider)
│   │   ├── api/v1/endpoints/    # Endpoints REST (chat, convos, attachments, billing, admin)
│   │   ├── core/                # Config, Security, Rate Limiter
│   │   ├── database/            # Connection manager pg8000 avec SSL & DNS cache
│   │   ├── repositories/        # Couche d'accès aux données Supabase
│   │   ├── schemas/             # Modèles Pydantic de validation
│   │   ├── services/            # Logique métier (chat, admin, stripe)
│   │   └── static/admin/        # Single Page App de la console Admin Web
│   ├── requirements.txt         # Dépendances Python auditées (0 CVE)
│   └── tests/                   # 49 tests automatisés pytest
├── mobile/
│   ├── android/                 # Configuration Android native, manifests, keystores
│   ├── lib/
│   │   ├── core/                # Thème Aura Obsidian, services, config API
│   │   └── features/            # Écrans et widgets (auth, chat, convos, premium)
│   ├── pubspec.yaml             # Dépendances Flutter & versioning 1.0.0+1
│   └── test/                    # 20 tests automatisés Flutter
└── docs/
    └── SD-CHAT-AI.md            # Source de vérité officielle du projet
```

---

## 10. Commandes Officielles de Build & Test

```bash
# Tests Backend FastAPI (49 tests)
cd /home/sekoudiaby433/SD-CHAT-AI/backend
PYTHONPATH=. /home/sekoudiaby433/SD-CHAT-AI/backend/venv/bin/pytest -v tests/

# Analyse Statique Flutter (0 issue)
cd /home/sekoudiaby433/SD-CHAT-AI/mobile
/home/sekoudiaby433/flutter/bin/flutter analyze

# Tests Flutter Unitaires & Widgets (20 tests)
/home/sekoudiaby433/flutter/bin/flutter test

# Génération APK RELEASE Signé
/home/sekoudiaby433/flutter/bin/flutter build apk --release

# Génération AAB RELEASE Signé (Google Play)
/home/sekoudiaby433/flutter/bin/flutter build appbundle --release
```

---

## 11. Fonctionnalités V1 vs Roadmap V2

### 11.1 Fonctionnalités Finalisées & Validées en V1
- [x] Authentification Google native Supabase avec session locale persistante.
- [x] Streaming conversationnel SSE ultra-réactif avec micro-batching 40 ms.
- [x] Moteur Google Gemini 3.6 Flash avec retry automatique sur surcharge 503/429.
- [x] Bouton d'interruption immédiate de réponse IA.
- [x] Dictée vocale Android avec prévisualisation et édition manuelle.
- [x] Téléversement et gestion des pièces jointes (images & fichiers texte jusqu'à 10 Mo).
- [x] Système de quotas Free (15 msg/j) vs Premium (500 msg/j).
- [x] Monétisation Stripe complète (Checkout Session, Customer Portal, Webhooks).
- [x] Console Web d'Administration `/admin` avec métriques, analytics Chart.js et audit logs.
- [x] Design System exclusif *Aura Obsidian & Amber-Platinum*.
- [x] Icône personnalisée professionnelle avec adaptive icon Android.
- [x] Row Level Security (RLS) sur 100% des tables PostgreSQL et stockage privé.
- [x] Artefacts APK et AAB Release signés et vérifiés pour Google Play.

### 11.2 Fonctionnalités Volontairement Prévues pour la V2
- [ ] Branchement du modèle propriétaire IA souverain SD (via `BaseLLMProvider`).
- [ ] Recherche sémantique vectorielle (Embeddings) dans l'historique des discussions.
- [ ] Prise en charge des documents PDF et documents bureautiques complexes.
- [ ] Synthèse vocale (Text-to-Speech) pour écouter les réponses de l'IA avec une voix SD dédiée.
- [ ] Mode multi-agents et personas spécialisés au sein de la même discussion.

---

## 12. Mission 21 — Stabilisation Réseau & Production Backend Render

- **URL Backend Production Définitive** : `https://sd-chat-ai-backend.onrender.com/api` (élimination intégrale des tunnels temporaires).
- **Détection Réseau Robuste & Découplée** :
  - `checkRealInternet()` teste l'accès Internet réel (socket direct `8.8.8.8:53` avec repli `google.com`) indépendamment de l'état du backend.
  - 4 états distincts gérés et affichés dynamiquement :
    - 🟢 **Connecté** : Internet fonctionnel + Backend Render en ligne.
    - 🟡 **Synchronisation** : Échange de données en cours.
    - 🟠 **Serveur temporairement indisponible** : Internet OK, mais backend distant injoignable (évite le faux positif « Hors ligne »).
    - 🔴 **Hors ligne** : Aucune connectivité Internet sur l'appareil.
- **Affichage Dynamique du Modèle IA** : Les bulles de messages affichent désormais le modèle réel rapporté par le backend (ex: `Gemini 3.6 Flash`) au lieu d'un libellé figé.
- **Artefact Release Vérifié** : `build/app/outputs/flutter-apk/app-release.apk` compilé avec l'URL de production, aucun tunnel, aucun localhost dans le code applicatif.

---

## 13. Mission Majeure — SD AI GATEWAY, Multi-Modèles, Abonnements & Paiements GNF

### 13.1 SD AI GATEWAY Multi-Providers
- **Architecture unifiée** : `BaseLLMProvider` implémenté par 5 adaptateurs officiels :
  - `GeminiProvider` (Google Gemini 3.6 Flash, 2.5 Flash, 1.5 Pro)
  - `OpenAIProvider` (GPT-4o, GPT-4o-mini, o3-mini)
  - `AnthropicProvider` (Claude 3.5 Sonnet, Claude 3.5 Haiku, Claude 3 Opus)
  - `XAIProvider` (Grok-2 1212)
  - `OpenRouterProvider` (DeepSeek V3, Llama 3.3 70B Instruct, Mistral Large)
- **Circuit Breaker résilient** : Détecte les indisponibilités (3 échecs consécutifs -> état `open`), période de refroidissement paramétrable, basculement en `half_open`, réinitialisation manuelle ou automatique.
- **Provider Router & Fallback intelligent** :
  - Routage transparent en cas d'erreur transitoire d'un fournisseur.
  - Décompte unique du quota par requête utilisateur (`check_and_consume_message_quota`), quel que soit le nombre de tentatives dans la chaîne de repli.
  - Événement final SSE enrichi : `message_id`, `model`, `provider`, `fallback_used`, métriques de latence et tokens.
- **Catalogue strict des modèles (`ModelsCatalog`)** :
  - Seuls les modèles réels officiels documentés sont actifs (`is_active=True`).
  - Dénominations commerciales ou futures (GPT 5.6, GPT 6 ASTRA, Claude Opus 5, Claude Sonnet 4) répertoriées avec `is_active=False` et statut `Non disponible`.

### 13.2 Les 4 Plans Officiels SD en Francs Guinéens (GNF)
| Plan SD | Tarif GNF | Quota Quotidien | Modèles Accessibles | Mémoire | Routage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SD FREE** | 0 GNF | 5 req/jour | Gemini économique (3.6 Flash) | Basique (5 msgs) | SD AI Gateway Auto |
| **SD PREMIUM** | 10 000 GNF/mois | 10 req/jour | Modèles premium autorisés | Mémoire conversationnelle | SD AI Gateway Auto |
| **SD VIP** | 50 000 GNF/mois | 25 req/jour | Modèles VIP + Sélection manuelle | Mémoire conversationnelle | Sélection libre + Auto fallback |
| **SD BLACK PREMIUM ULTRA** | 250 000 GNF/mois | Haute capacité Fair Use (200 req/j) | Flagships (GPT-4o, Claude 3.5 Sonnet, Grok-2) | Priorité SD maximale | Sélection libre + Fallback renforcé |

### 13.3 Passerelles de Paiement Extensibles & Mobile Money
- **Architecture unifiée** : `BasePaymentAdapter` avec registre dynamique (`list_available_payment_methods`).
- **Stripe Adapter** : Paiement international par carte bancaire.
- **Mobile Money Guinée Adapter** : Prise en charge officielle Orange Money Guinée & MTN MoMo Guinée en GNF.
- **Règle Zéro Fake Mock** : Rejet explicite avec exigences marchandes précises (`MERCHANT_ID`, `API_KEY`) si les identifiants réels ne sont pas renseignés dans l'environnement.

### 13.4 Flutter Mobile App & Expérience Utilisateur
- **Sélecteur de modèle dans l'AppBar** :
  - Utilisateurs VIP / Black : dialogue de sélection parmi les modèles réels actifs autorisés.
  - Utilisateurs Free / Premium : dialogue informatif expliquant l'optimisation automatique du SD AI Gateway et CTA de mise à niveau vers SD VIP.
- **Grille comparative des 4 plans SD** :
  - Écran Premium officiel avec affichage des tarifs en GNF.
  - Comparateur visuel des fonctionnalités (quotas, modèles, mémoire, priorité).
  - Modal de sélection du moyen de paiement (Stripe ou Mobile Money).
  - Respect scrupuleux de la charte *Aura Obsidian & Amber-Platinum*.

---

## 14. Mission — Centre « Paramètres » Officiel dans le Profil

### 14.1 Architecture & Entrée Profil
- **Accès Profil & Tiroir Latéral** :
  - Dans le tiroir latéral (`ConversationsDrawer`), ajout d'une entrée officielle et visible : « ⚙️ Paramètres » avec icône de roue crantée.
  - Le pied de page utilisateur (avatar, nom, email) est également tactile et ouvre directement le centre de contrôle des paramètres.
- **Hub Central en 10 Sections (`SettingsScreen`)** :
  - **1. Paramètres du compte** :
    - Gestion de l'avatar utilisateur avec upload réel (`POST /api/v1/profile/avatar`) vers le bucket Supabase `avatars`.
    - Sélecteur de source d'image (Galerie ou Appareil photo via `image_picker`).
    - Modification du nom complet (`PATCH /api/v1/profile`).
    - Affichage de l'adresse email et de la méthode de connexion (Google Auth ou Email/Mot de passe).
    - Affichage du rôle (Administrateur / Utilisateur) et du plan actif.
  - **2. Contrôle des données** :
    - *A. Vider le cache* : Calcul dynamique de la taille du cache temporaire (`getTemporaryDirectory()`) et suppression instantanée avec notification.
    - *B. Effacer les données locales* : Purge de l'historique et des messages mis en cache SQLite localement (`LocalDatabaseService.instance.clearAllLocalData`).
    - *C. Supprimer les données cloud* : Endpoint authentifié `DELETE /api/v1/data/cloud` supprimant définitivement discussions, messages et partages distants.
    - *D. Supprimer mon compte* : Endpoint authentifié `DELETE /api/v1/users/me` avec confirmation par saisie explicite de « SUPPRIMER », suppression de toutes les données et déconnexion immédiate.
    - *E. Liens partagés* : Gestionnaire complet (`SharedLinksScreen`) listant les liens créés, compteurs de vues, copie dans le presse-papiers, ouverture externe et révocation publique (`DELETE /api/v1/conversations/shared/{id}`).
  - **3. Langue** :
    - Bottom sheet interactive (`LanguageSelectorSheet`) avec 🇫🇷 Français (par défaut) et 🇬🇧 English.
    - Préparation explicite pour les langues régionales : N'Ko (ߒߞߏ), ADLaM (𞤀𞤣𞤤𞤢𞤥) et Susu (Sosoxui).
    - Persistance locale dans `SharedPreferences` et réactivité instantanée de l'application via `SettingsService`.
  - **4. Apparence** :
    - Bottom sheet interactive (`AppearanceSelectorSheet`) avec Sombre permanent (Aura Obsidian), Clair permanent (Titane Platine) et Système (adapté à l'OS).
    - Moteur de thèmes dynamique `SDChatTheme.buildTheme` préservant l'ADN de marque.
  - **5. Taille de la police** :
    - Slider interactif à 4 paliers (Petit, Normal, Grand, Très grand) avec aperçu en temps réel (`FontSizeSliderSheet`).
    - Répercussion dynamique sur la typographie des bulles de messages IA et du moteur de rendu Markdown (`MessageBubble`).
  - **6. Personnalisation** :
    - Palette officielle des 6 couleurs d'accentuation (`AccentColorPickerSheet`) :
      - 🔵 Bleu (`#3B82F6`)
      - 🟢 Vert (`#10B981`)
      - 🔴 Rouge (`#EF4444`)
      - 🟠 Orange (`#F97316`)
      - 🟡 Jaune / Aura Amber officiel (`#E5A93C`)
      - 🟣 Violet (`#8B5CF6`)
    - Coloration dynamique réactive de l'AppBar, des boutons d'action et des highlights applicatifs.
  - **7. Vérifier les mises à jour** :
    - Vérification en direct auprès de `/api/v1/app/version-check`.
    - Affichage de la version installée (`v1.0.0`), de la version serveur et du package officiel `com.sd.chat.sd_chat_ai`.
    - Bouton officiel de redirection vers le Google Play Store en cas de mise à jour disponible.
  - **8. Contrat de service** :
    - 4 documents légaux structurés sous forme d'onglets (`TermsOfServiceScreen`) :
      1. *Politique de confidentialité* (chiffrement TLS 1.3, isolation RLS Supabase, non-entraînement sur données privées).
      2. *Licence logicielle* (Propriété intellectuelle exclusive de Sekou Diaby / SD, restrictions d'usage).
      3. *À propos de SD* (Sekou Diaby, « SD — Build the Future with AI », vision démocratique de l'IA).
      4. *Abonnements et paiements* (Stripe, Mobile Money, forfaits et modalités de résiliation).
  - **9. Aide et commentaires** :
    - Formulaire d'assistance complet (`HelpFeedbackScreen`) : Type de demande (Bug, Suggestion, Facturation, Autre), sujet, description détaillée, capture d'écran optionnelle.
    - Diagnostics techniques pré-remplis (Plateforme, OS, Version, Build).
    - Enregistrement sécurisé en base PostgreSQL (`public.user_feedback`) et notification au support SD : `sd.ai.founder@gmail.com`.
  - **10. Déconnexion** :
    - Bouton rouge distinct en bas du centre de paramètres avec dialogue de confirmation (`LogoutConfirmDialog`).
    - Fermeture sécurisée de la session (Google Auth et Email/Mot de passe), nettoyage des jetons et redirection immédiate vers l'écran de connexion.

### 14.2 Base de Données Supabase & Endpoints Backend
- Nouvelles tables PostgreSQL SD-DEV :
  - `public.shared_conversations` : `id`, `conversation_id`, `user_id`, `title`, `share_token`, `is_revoked`, `views_count`, `created_at`, `revoked_at` avec RLS activé.
  - `public.user_feedback` : `id`, `user_id`, `email`, `category`, `subject`, `description`, `device_info`, `status`, `created_at` avec RLS activé.
  - Configuration du bucket Supabase Storage `avatars` en accès public pour les photos de profil.
- Endpoints FastAPI (`/api/v1`) :
  - `GET /api/v1/profile` & `PATCH /api/v1/profile`
  - `POST /api/v1/profile/avatar`
  - `DELETE /api/v1/data/cloud`
  - `DELETE /api/v1/users/me`
  - `POST /api/v1/conversations/{conversation_id}/share`
  - `GET /api/v1/conversations/shared/links`
  - `DELETE /api/v1/conversations/shared/{share_id}`
  - `GET /api/v1/conversations/public/{share_token}`
  - `POST /api/v1/support/feedback`
  - `GET /api/v1/app/version-check`
- **Validation** :
  - Backend pytest : 5/5 tests validés (`backend/tests/test_settings.py`), 6/6 tests passerelle validés (`backend/tests/test_gateway.py`).
  - Mobile Flutter : 11/11 tests unitaires et widget validés (`mobile/test/settings_test.dart`, `mobile/test/settings_widget_test.dart`).
  - Analyse statique Flutter : 0 warning, 0 error (`flutter analyze`).
  - Compilation Release : APK finalisé avec succès (`mobile/build/app/outputs/flutter-apk/app-release.apk` - 63.9 MB).


