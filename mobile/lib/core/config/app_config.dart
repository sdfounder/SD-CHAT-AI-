class AppConfig {
  static const String appName = 'SD CHAT AI';
  static const String appVersion = '1.0.0';
  static const String slogan = 'SD — Build the Future with AI';
  static const String creator = 'Sekou Diaby';

  // Point de terminaison de l'API Backend FastAPI Cloud HTTPS
  // Communique directement via HTTPS sans passer par localhost
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bwmxy-197-149-244-22.free.pinggy.net/api',
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

  // Modèle IA par défaut géré exclusivement côté backend
  static const String defaultModel = 'gemini-3.6-flash';
}
