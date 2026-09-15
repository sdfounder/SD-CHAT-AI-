#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

export PYTHONPATH="$SCRIPT_DIR:$SCRIPT_DIR/venv/lib/python3.11/site-packages"

echo "=== Lancement du Backend SD CHAT AI (FastAPI / Uvicorn) ==="
echo "Environnement : $(grep ENVIRONMENT .env | cut -d '=' -f2)"
echo "Base de données : PostgreSQL Supabase SD-DEV"
echo "Moteur IA : Google Gemini 3.6 Flash"
echo "Port : 8000"

exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
