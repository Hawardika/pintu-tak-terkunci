-- Pintu Tak Terkunci — Supabase setup
-- Jalankan script ini di Supabase SQL Editor.

create table if not exists public.quiz_responses (
  id bigint generated always as identity primary key,
  session_id text not null unique,
  score smallint not null check (score between 0 and 4),
  max_score smallint not null check (max_score = 4),
  answers jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.quiz_responses enable row level security;

-- Browser peserta hanya boleh INSERT hasil quiz.
grant insert on public.quiz_responses to anon;

create policy "public can submit quiz response"
on public.quiz_responses
for insert
to anon
with check (
  char_length(session_id) between 4 and 64
  and jsonb_typeof(answers) = 'array'
  and score between 0 and 4
  and max_score = 4
);

-- Dashboard tidak membaca tabel mentah. Ia hanya membaca agregat dari function ini.
create or replace function public.get_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'count', count(*),
    'avg', coalesce(round(avg(score)::numeric, 1), 0),
    'byChapter', jsonb_build_object(
      'wireless', jsonb_build_object(
        'good', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='wireless' and a->>'outcome'='good'),0),
        'total', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='wireless'),0)
      ),
      'bluetooth', jsonb_build_object(
        'good', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='bluetooth' and a->>'outcome'='good'),0),
        'total', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='bluetooth'),0)
      ),
      'mobile', jsonb_build_object(
        'good', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='mobile' and a->>'outcome'='good'),0),
        'total', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='mobile'),0)
      ),
      'byod', jsonb_build_object(
        'good', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='byod' and a->>'outcome'='good'),0),
        'total', coalesce((select count(*) from public.quiz_responses r, jsonb_array_elements(r.answers) a where a->>'chapter'='byod'),0)
      )
    )
  ) into result
  from public.quiz_responses;

  return result;
end;
$$;

revoke all on function public.get_dashboard_stats() from public;
grant execute on function public.get_dashboard_stats() to anon;

-- Sequence privilege diperlukan agar INSERT dengan identity column bisa berjalan.
grant usage, select on sequence public.quiz_responses_id_seq to anon;
