-- ============================================================================
-- PKBM MAJU JAYA - SETUP DATABASE SUPABASE (jalankan SEKALI, aman diulang)
-- Supabase Dashboard > SQL Editor > New query > tempel semua > Run
-- ============================================================================

-- 1. TABEL (dibuat jika belum ada) ------------------------------------------
create table if not exists public.tutor_guru (
  id text primary key
);
create table if not exists public.warga_belajar (
  id text primary key
);
create table if not exists public.jadwal_modul (
  id text primary key
);
create table if not exists public.presensi (
  id text primary key
);
create table if not exists public.penilaian (
  id text primary key
);
create table if not exists public.administrasi_kas (
  id text primary key
);
create table if not exists public.raport (
  id text primary key
);
create table if not exists public.app_settings (
  key text primary key
);

-- 2. KOLOM (ditambahkan jika belum ada; tidak mengubah kolom yang sudah ada) --
alter table public.tutor_guru
  add column if not exists nip_guru text,
  add column if not exists nama_lengkap text,
  add column if not exists mata_pelajaran text,
  add column if not exists no_hp text,
  add column if not exists password text,
  add column if not exists created_at timestamptz default now();

alter table public.warga_belajar
  add column if not exists nisn text,
  add column if not exists nama_lengkap text,
  add column if not exists paket text,
  add column if not exists tingkat text,
  add column if not exists jenis_kelamin text,
  add column if not exists no_hp text,
  add column if not exists alamat text,
  add column if not exists status text,
  add column if not exists password text,
  add column if not exists created_at timestamptz default now();

alter table public.jadwal_modul
  add column if not exists paket text,
  add column if not exists mata_pelajaran text,
  add column if not exists tutor_nama text,
  add column if not exists hari_waktu text,
  add column if not exists link_modul text,
  add column if not exists keterangan text,
  add column if not exists created_at timestamptz default now();

alter table public.presensi
  add column if not exists warga_belajar_id text,
  add column if not exists tanggal text,
  add column if not exists paket text,
  add column if not exists status_kehadiran text,
  add column if not exists keterangan text,
  add column if not exists created_at timestamptz default now();

alter table public.penilaian
  add column if not exists warga_belajar_id text,
  add column if not exists paket text,
  add column if not exists mapel text,
  add column if not exists jenis text,
  add column if not exists nilai numeric,
  add column if not exists catatan text,
  add column if not exists created_at timestamptz default now();

alter table public.administrasi_kas
  add column if not exists tanggal text,
  add column if not exists kategori text,
  add column if not exists tipe text,
  add column if not exists jumlah numeric,
  add column if not exists keterangan text,
  add column if not exists created_at timestamptz default now();

alter table public.raport
  add column if not exists warga_belajar_id text,
  add column if not exists wali_kelas_nama text,
  add column if not exists wali_kelas_nip text,
  add column if not exists kepala_pkbm_nama text,
  add column if not exists kepala_pkbm_nip text,
  add column if not exists kota_terbit text,
  add column if not exists tanggal_terbit text,
  add column if not exists tahun_ajaran text,
  add column if not exists semester text,
  add column if not exists catatan_wali text,
  add column if not exists predikat_sikap text,
  add column if not exists status_kenaikan text,
  add column if not exists nilai_mapel jsonb default '[]'::jsonb,
  add column if not exists created_at timestamptz default now();

alter table public.app_settings
  add column if not exists value jsonb,
  add column if not exists updated_at timestamptz default now();

-- 3. ROW LEVEL SECURITY -------------------------------------------------------
-- Admin  = akun Supabase Auth (role "authenticated")  -> akses penuh.
-- Guru / siswa login lewat tabel aplikasi (role "anon") -> dibatasi:
--   * baca: semua tabel kecuali administrasi_kas
--   * tulis: hanya jadwal_modul, presensi, penilaian, raport
--   * kolom password TIDAK bisa dibaca anon (lihat bagian 4)
alter table public.tutor_guru       enable row level security;
alter table public.warga_belajar    enable row level security;
alter table public.jadwal_modul     enable row level security;
alter table public.presensi         enable row level security;
alter table public.penilaian        enable row level security;
alter table public.administrasi_kas enable row level security;
alter table public.raport           enable row level security;
alter table public.app_settings     enable row level security;

-- Bersihkan kebijakan lama (termasuk 2 kebijakan bawaan yang pernah dibuat)
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('tutor_guru','warga_belajar','jadwal_modul','presensi',
                        'penilaian','administrasi_kas','raport','app_settings')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Admin: akses penuh ke semua tabel
do $$
declare t text;
begin
  foreach t in array array['tutor_guru','warga_belajar','jadwal_modul','presensi',
                           'penilaian','administrasi_kas','raport','app_settings']
  loop
    execute format('create policy %I on public.%I for all to authenticated using (true) with check (true)',
                   'admin_all_' || t, t);
  end loop;
end $$;

-- Guru/siswa (anon): baca
do $$
declare t text;
begin
  foreach t in array array['tutor_guru','warga_belajar','jadwal_modul','presensi',
                           'penilaian','raport','app_settings']
  loop
    execute format('create policy %I on public.%I for select to anon using (true)',
                   'anon_read_' || t, t);
  end loop;
end $$;

-- Guru (anon): tulis hanya pada tabel kerja guru
do $$
declare t text;
begin
  foreach t in array array['jadwal_modul','presensi','penilaian','raport']
  loop
    execute format('create policy %I on public.%I for insert to anon with check (true)', 'anon_insert_' || t, t);
    execute format('create policy %I on public.%I for update to anon using (true) with check (true)', 'anon_update_' || t, t);
    execute format('create policy %I on public.%I for delete to anon using (true)', 'anon_delete_' || t, t);
  end loop;
end $$;

-- 4. SEMBUNYIKAN KOLOM PASSWORD DARI ANON ------------------------------------
-- anon hanya boleh membaca kolom selain "password".
do $$
declare t text; cols text;
begin
  foreach t in array array['tutor_guru','warga_belajar']
  loop
    execute format('revoke select on public.%I from anon', t);
    select string_agg(format('%I', column_name), ', ' order by ordinal_position)
      into cols
      from information_schema.columns
      where table_schema = 'public' and table_name = t and column_name <> 'password';
    execute format('grant select (%s) on public.%I to anon', cols, t);
  end loop;
end $$;

-- 5. FUNGSI LOGIN GURU / SISWA (memeriksa password di sisi server) ------------
create or replace function public.login_guru(p_identifier text, p_password text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(g) - 'password' - 'created_at'
  from public.tutor_guru g
  where length(coalesce(p_identifier, '')) > 0
    and g.password is not null
    and g.password = p_password
    and (
      lower(coalesce(g.nip_guru, '')) = lower(p_identifier)
      or g.id = p_identifier
      or lower(coalesce(g.nama_lengkap, '')) like '%' || lower(p_identifier) || '%'
    )
  limit 1;
$$;

create or replace function public.login_siswa(p_identifier text, p_password text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(s) - 'password' - 'created_at'
  from public.warga_belajar s
  where length(coalesce(p_identifier, '')) > 0
    and s.password is not null
    and s.password = p_password
    and (s.nisn = p_identifier or s.id = p_identifier)
  limit 1;
$$;

revoke all on function public.login_guru(text, text)  from public;
revoke all on function public.login_siswa(text, text) from public;
grant execute on function public.login_guru(text, text)  to anon, authenticated;
grant execute on function public.login_siswa(text, text) to anon, authenticated;

-- 6. FUNGSI UKUR PENYIMPANAN (menu Pengaturan, khusus admin) -----------------
create or replace function public.get_db_usage()
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'authenticated' then
    raise exception 'Akses ditolak';
  end if;
  return json_build_object(
    'db_bytes', pg_database_size(current_database()),
    'tables', (
      select coalesce(json_agg(json_build_object('name', c.relname, 'bytes', pg_total_relation_size(c.oid)) order by pg_total_relation_size(c.oid) desc), '[]'::json)
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind = 'r'
    )
  );
end;
$$;

revoke all on function public.get_db_usage() from public, anon;
grant execute on function public.get_db_usage() to authenticated;

-- Selesai. Muat ulang schema cache PostgREST agar kolom/fungsi baru langsung terbaca:
notify pgrst, 'reload schema';
