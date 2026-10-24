// ============================================================================
// KONFIGURASI SUPABASE - isi SEKALI, lalu push ke GitHub.
// Dengan file ini semua perangkat (admin, guru, siswa) otomatis terhubung ke
// database yang sama, tanpa perlu mengisi "Koneksi Supabase" satu per satu.
//
// Ambil di: Supabase Dashboard > Project Settings > API
//   - Project URL           -> SUPABASE_URL
//   - anon / public key     -> SUPABASE_ANON_KEY
//
// PENTING: isi HANYA "anon public" key. JANGAN PERNAH memakai "service_role" key.
// ============================================================================
window.PKBM_CONFIG = {
  SUPABASE_URL: "https://qnjkiwkfvyptbrfajjir.supabase.co",        // contoh: "https://abcdefghijk.supabase.co"
  SUPABASE_ANON_KEY: "sb_publishable_h84U9vs2KawMf08qwD7LFg_jH2aQGIP"    // contoh: "eyJhbGciOiJIUzI1NiIsInR5cCI6..."
};
