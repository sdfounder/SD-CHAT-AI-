import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

url = os.getenv("SUPABASE_URL", "https://placeholder.supabase.co")
key = os.getenv("SUPABASE_KEY", "placeholder-key")

supabase: Client = create_client(url, key)

