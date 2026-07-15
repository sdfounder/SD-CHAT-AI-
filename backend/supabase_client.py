from supabase import create_client

url = "https://zrjbqdhibotnwudbrcwv.supabase.co/rest/v1/"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpyamJxZGhpYm90bnd1ZGJyY3d2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwMzM2MjAsImV4cCI6MjA5OTYwOTYyMH0.uh8sUWw7lf4cQFxNjM9s2TFU-CrPkqPsEOeBehSNQuM"

supabase = create_client(url, key)
