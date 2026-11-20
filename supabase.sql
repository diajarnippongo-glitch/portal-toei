-- Portal TOEI: jalankan seluruh isi file ini di Supabase > SQL Editor > Run
create table profiles(id uuid primary key references auth.users on delete cascade, nama text, role text not null default 'tunggu' check (role in ('admin','sensei','guest','tunggu')));
create table kelas(id text primary key, nama text not null, data jsonb not null default '{}');
create table penugasan(user_id uuid references profiles on delete cascade, kelas_id text references kelas on delete cascade, primary key(user_id,kelas_id));
alter table profiles enable row level security;
alter table kelas enable row level security;
alter table penugasan enable row level security;

create function public.peran() returns text language sql security definer set search_path=public stable as $$select role from profiles where id=auth.uid()$$;
create function public.punya_kelas(k text) returns boolean language sql security definer set search_path=public stable as $$select exists(select 1 from penugasan where user_id=auth.uid() and kelas_id=k)$$;
-- akun pertama yang mendaftar otomatis jadi admin, selanjutnya menunggu persetujuan
create function public.baru() returns trigger language plpgsql security definer set search_path=public as $$begin insert into profiles(id,nama,role) values(new.id,coalesce(new.raw_user_meta_data->>'nama',new.email),case when not exists(select 1 from profiles) then 'admin' else 'tunggu' end);return new;end$$;
create trigger akun_baru after insert on auth.users for each row execute function public.baru();

create policy p_baca on profiles for select using (id=auth.uid() or peran()='admin');
create policy p_ubah on profiles for update using (peran()='admin');
create policy k_baca on kelas for select using (peran() in ('admin','guest') or (peran()='sensei' and punya_kelas(id)));
create policy k_ubah on kelas for update using (peran()='admin' or (peran()='sensei' and punya_kelas(id)));
create policy k_tambah on kelas for insert with check (peran()='admin');
create policy k_hapus on kelas for delete using (peran()='admin');
create policy a_baca on penugasan for select using (user_id=auth.uid() or peran()='admin');
create policy a_tulis on penugasan for all using (peran()='admin') with check (peran()='admin');
