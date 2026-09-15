# SD CHAT AI — Application d'Intelligence Conversationnelle SD

**Version :** 1.0.0-socle  
**Écosystème :** SD — Build the Future with AI  
**Fondateur :** Sekou Diaby  
**Statut :** Mission 1 — Socle Réel Finalisé  

---

## 1. Vision & Architecture

SD CHAT AI est la plateforme d'intelligence conversationnelle souveraine et avancée de l'écosystème SD.
L'application repose sur un découpage strict et modulaire :

- **Frontend Mobile** : Flutter / Dart multiplateforme (Android, iOS, Web).
- **Backend Orchestrateur** : Python 3.11+ / FastAPI asynchrone avec streaming Server-Sent Events (SSE).
- **Persistance & Données** : Supabase PostgreSQL (SD-DEV : `ryvmacsmfvllhgbqbnkb`, SD-CORE à venir).
- **Authentification** : Google OAuth via Supabase Auth (indépendante de SD Account pour la V1).
- **Moteur IA** : Google Gemini API (`gemini-3.6-flash`) via une couche d'abstraction (`BaseLLMProvider`) permettant un remplacement transparent par un futur modèle propriétaire SD.
- **Sécurité** : Zéro clé secrète dans le client Flutter. Validation cryptographique des jetons JWT et Row Level Security (RLS) sur 100% des tables.

---

## 2. Identité Visuelle Unique 2026

Conformément aux directives de design 2026 :
- **Palette "Aura Obsidian & Amber-Platinum"** :
  - Fond : Noir Profond Titane (`#08090A`, `#0E1013`)
  - Surfaces : Graphite Mat (`#14171B`, `#1C2026`)
  - Accent Lumineux : Aura Amber (`#E5A93C`, `#F5B744`)
  - Bordures : Titane Foncé (`#1F242B`, `#2D333D`)
  - Textes : Blanc Pur (`#F8FAFC`) et Zinc Muted (`#94A3B8`)
- **Typographie** : Inter / Google Fonts avec rendu Markdown propre et blocs de code avec coloration syntaxique.
- **Animations** : Indicateur de pulsation ambrée, transition fluide de frappe.

---

## 3. Structure du Projet

```
SD-CHAT-AI/
├── backend/                          # FastAPI Python
│   ├── .env                          # Variables locales (gitignored)
│   ├── run_backend.sh                # Script de lancement Uvicorn
│   ├── app/
│   │   ├── main.py                   # Point d'entrée FastAPI
│   │   ├── core/
│   │   │   ├── config.py             # Configuration pydantic-settings
│   │   │   └── security.py           # Vérification JWT Supabase & AuthenticatedUser
│   │   ├── ai/
│   │   │   ├── base_provider.py      # Interface abstraite BaseLLMProvider
│   │   │   ├── gemini_provider.py    # Fournisseur Google Gemini V1 (SSE Streaming)
│   │   │   └── __init__.py           # Factory get_ai_provider()
│   │   ├── database/
│   │   │   └── connection.py         # Connexion directe PostgreSQL pooler
│   │   ├── schemas/
│   │   │   └── chat_schemas.py       # Modèles Pydantic Request/Response
│   │   ├── repositories/
│   │   │   └── chat_repository.py    # Persistance SQL (conversations, messages)
│   │   ├── services/
│   │   │   └── chat_service.py       # Orchestration streaming SSE + persistence
│   │   └── api/v1/
│   │       ├── endpoints/            # chat.py, conversations.py, health.py
│   │       └── router.py
│   └── tests/                        # Tests automatisés pytest
├── mobile/                           # Application Flutter / Dart
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart                 # Point d'entrée Flutter
│       ├── core/
│       │   ├── config/app_config.dart
│       │   ├── theme/                # sd_chat_colors.dart, sd_chat_theme.dart
│       │   └── services/             # auth_service.dart, chat_api_service.dart
│       ├── features/
│       │   ├── auth/screens/login_screen.dart
│       │   ├── chat/                 # chat_screen.dart, widgets/
│       │   └── conversations/widgets/conversations_drawer.dart
│       └── shared/models/            # conversation.dart, chat_message.dart
└── database/migrations/
    └── 01_sd_chat_ai_schema.sql      # Schéma déployé sur Supabase SD-DEV
```

---

## 4. Démarrage Rapide

### Backend :
```bash
cd backend
./run_backend.sh
```

### Application Mobile Flutter :
```bash
cd mobile
flutter run
```
