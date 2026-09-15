import os
from dotenv import load_dotenv
from supabase import create_client, Client

# Charger les variables du fichier .env
load_dotenv()

# Récupérer les informations Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://placeholder.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "placeholder-key")

# Créer le client Supabase
supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_KEY
)
