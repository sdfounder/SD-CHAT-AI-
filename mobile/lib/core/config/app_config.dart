class AppConfig {
  static const String appName = 'SD CHAT AI';
  static const String appVersion = '1.0.0';
  static const String slogan = 'SD — Build the Future with AI';
  static const String creator = 'Sekou Diaby';

  // Point de terminaison de l'API Backend FastAPI Cloud HTTPS (Render Production)
  // Communique directement via HTTPS sécurisé officiel sans aucun tunnel temporaire
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sd-chat-ai-backend.onrender.com/api',
  );

  // Configuration Supabase SD-DEV (Authentification Google uniquement)
  // AUCUNE clé privée ou secrète dans Flutter — uniquement l'anon key publique
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ryvmacsmfvllhgbqbnkb.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ5dm1hY3NtZnZsbGhnYnFibnFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQwMzM2MjAsImV4cCI6MjA5OTYwOTYyMH0.placeholder',
  );

  // Modèle IA de référence V1 géré côté backend
  static const String defaultModel = 'gemini-3.6-flash';
}
