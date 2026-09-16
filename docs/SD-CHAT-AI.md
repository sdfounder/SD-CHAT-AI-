# SD CHAT AI — Documentation Officielle du Projet & Architecture

> **Écosystème SD** : « SD — Build the Future with AI »  
> **Créateur & Fondateur** : Sekou Diaby  
> **Source de Vérité** : `docs/SD-CHAT-AI.md`

---

## 1. Vue d'ensemble

**SD CHAT AI** est l'application conversationnelle intelligente d'élite de l'écosystème SD. Elle combine une expérience utilisateur mobile ultra-soignée (thème *Aura Obsidian & Amber-Platinum*), un backend FastAPI haute performance en streaming SSE temps réel, le modèle d'IA Google Gemini (V1), et la persistance sur l'infrastructure Cloud Supabase (SD-DEV).

---

## 2. Architecture Technique

### 2.1 Backend (FastAPI + Python 3.11)
- **Framework** : FastAPI asynchrone avec Uvicorn.
- **Streaming** : Server-Sent Events (SSE) via `POST /api/v1/chat/stream`.
- **Moteur IA** : Google Gemini via `google-genai` / SDK officiel. Clé API strictement confinée au backend.
- **Sécurité** : Validation des JWT Supabase (`sub` = `user_id`), CORS configuré, headers de sécurité.
- **Connecteur Base de Données** : `DatabaseConnectionManager` (pg8000 native) avec pré-résolution DNS d'adresse IP (`aws-1-eu-west-1.pooler.supabase.com`), contexte SSL direct, et rafraîchissement proactif évitant les latences de handshake.

### 2.2 Frontend Mobile (Flutter 3.x / Dart)
- **Design System** : *Aura Obsidian & Amber-Platinum* (fond noir obsidienne profond `#08090C`, carte anthracite `#12151B`, or ambré `#D4AF37`, platine `#E5E4E2`).
- **Rendu Markdown** : Formattage Markdown complet avec coloration syntaxique et copie de code en 1 clic.
- **Contrôle du flux** : Bouton d'interruption immédiate de génération (`ChatStreamHandle.cancel()`).
- **Dictée Vocale** : Intégration native Android Speech-to-Text (`speech_to_text`), bouton 🎙️ interactif avec pulsation ambrée, modification avant envoi, respect de la confidentialité.
- **Gestion des Pièces Jointes (Mission 5)** :
  - Images (`image_picker`) : JPEG, PNG, WebP, GIF (jusqu'à 10 Mo).
  - Documents texte (`file_picker`) : `.txt`, `.md`, `.csv`, `.log` (jusqu'à 10 Mo).
  - Prévisualisation immédiate en puces horizontales au-dessus du champ de message.
  - Possibilité de suppression instantanée avant envoi.
  - Visualiseur plein écran pour les images avec zoom/pan (`InteractiveViewer`).
  - Modal BottomSheet de lecture pour les fichiers texte avec police monospace.

---

## 3. Modèle de Données Supabase (SD-DEV)

### 3.1 `public.chat_conversations`
- `id` : UUID PRIMARY KEY
- `user_id` : UUID REFERENCES profiles(id)
- `title` : TEXT
- `model` : TEXT
- `system_prompt` : TEXT (nullable)
- `is_archived` : BOOLEAN DEFAULT FALSE
- `is_pinned` : BOOLEAN DEFAULT FALSE
- `created_at` : TIMESTAMPTZ
- `updated_at` : TIMESTAMPTZ

### 3.2 `public.chat_messages`
- `id` : UUID PRIMARY KEY
- `conversation_id` : UUID REFERENCES chat_conversations(id) ON DELETE CASCADE
- `user_id` : UUID
- `role` : TEXT ('user', 'assistant', 'system')
- `content` : TEXT
- `tokens_used` : INTEGER
- `model` : TEXT
- `created_at` : TIMESTAMPTZ

### 3.3 `public.chat_attachments`
- `id` : UUID PRIMARY KEY
- `conversation_id` : UUID REFERENCES chat_conversations(id) ON DELETE SET NULL
- `message_id` : UUID REFERENCES chat_messages(id) ON DELETE SET NULL
- `user_id` : UUID NOT NULL
- `file_name` : TEXT NOT NULL
- `file_type` : TEXT NOT NULL ('image' ou 'text')
- `storage_path` : TEXT NOT NULL
- `mime_type` : TEXT NOT NULL
- `file_size_bytes` : BIGINT NOT NULL
- `created_at` : TIMESTAMPTZ NOT NULL

### 3.4 `public.chat_attachment_blobs`
- `attachment_id` : UUID PRIMARY KEY REFERENCES chat_attachments(id) ON DELETE CASCADE
- `content_bytes` : BYTEA NOT NULL
- `created_at` : TIMESTAMPTZ NOT NULL

---

## 4. API Endpoints — Pièces Jointes

| Méthode | Route | Description | Sécurité |
|---|---|---|---|
| `POST` | `/api/v1/attachments/upload` | Téléversement sécurisé multipart (max 10 Mo) | Auth Bearer JWT |
| `GET` | `/api/v1/attachments/{id}` | Métadonnées de la pièce jointe | Propriétaire uniquement |
| `GET` | `/api/v1/attachments/{id}/raw` | Flux binaire brut sécurisé avec Content-Type | Propriétaire uniquement |
| `DELETE` | `/api/v1/attachments/{id}` | Suppression définitive (cascade sur le blob) | Propriétaire uniquement |

---

## 5. Tests & Qualité

- **Backend Pytest** :
  - `tests/test_attachments.py` : 5 tests automatisés (sécurité unauth 401, fichier vide 400, format invalide 400, dépassement taille > 10 Mo 413, cycle de vie complet upload/raw/rattachement/suppression).
- **Flutter Analyzer & Tests** :
  - `flutter analyze` : 0 issue, code propre et formatté.
  - `test/attachment_test.dart` : 4 tests validés (modèle `ChatAttachment`, `ChatMessage`, bouton trombone, widget `MessageAttachmentsView`).
  - `test/voice_input_test.dart` : 3 tests validés (dictée vocale).
