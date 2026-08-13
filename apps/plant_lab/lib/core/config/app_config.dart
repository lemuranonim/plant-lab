// Reads from --dart-define at build time
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bstxdyyglxrrfqgohllz.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdHhkeXlnbHhycmZxZ29obGx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MzIwMjcsImV4cCI6MjA3MzEwODAyN30.3eB08aX-Nltd8DPqk7sIWH6b8r4clPbgmIeEdyCV5Uk',
  );
}
