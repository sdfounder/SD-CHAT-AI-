from app.database.supabase import supabase


class AuthService:

    @staticmethod
    def sign_up(email: str, password: str):
        response = supabase.auth.sign_up({
            "email": email,
            "password": password
        })
        return response

    @staticmethod
    def sign_in(email: str, password: str):
        response = supabase.auth.sign_in_with_password({
            "email": email,
            "password": password
        })
        return response

    @staticmethod
    def sign_out():
        supabase.auth.sign_out()
