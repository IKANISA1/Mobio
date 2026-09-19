begin;

-- Create a missing bucket atomically before taking its row lock. Two first
-- requests must not race a SELECT-missing / INSERT sequence. Read the clock
-- after obtaining the lock so window resets and retry delays include the wait.
create or replace function public.consume_otp_rate_limit(
  p_bucket_key text,
  p_window_seconds integer,
  p_max_requests integer
)
returns table (
  allowed boolean,
  request_count integer,
  retry_after_seconds integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bucket public.otp_rate_limits%rowtype;
  v_now timestamptz;
  v_window interval;
begin
  if p_bucket_key is null
     or length(trim(p_bucket_key)) < 32
     or p_window_seconds is null
     or p_window_seconds < 1
     or p_max_requests is null
     or p_max_requests < 1 then
    raise exception 'Invalid OTP rate limit parameters.';
  end if;

  v_window := make_interval(secs => p_window_seconds);

  loop
    insert into public.otp_rate_limits (
      bucket_key, request_count, window_started_at, updated_at
    )
    values (p_bucket_key, 0, clock_timestamp(), clock_timestamp())
    on conflict (bucket_key) do nothing;

    select * into v_bucket
    from public.otp_rate_limits
    where bucket_key = p_bucket_key
    for update;

    -- A concurrent maintenance deletion may win between the insert conflict
    -- check and the SELECT. Recreate that bucket rather than returning nulls.
    exit when found;
  end loop;

  v_now := clock_timestamp();

  if v_bucket.window_started_at <= v_now - v_window then
    update public.otp_rate_limits
    set request_count = 1, window_started_at = v_now, updated_at = v_now
    where bucket_key = p_bucket_key
    returning * into v_bucket;

    return query select true, v_bucket.request_count, 0;
    return;
  end if;

  if v_bucket.request_count < p_max_requests then
    update public.otp_rate_limits
    set request_count = public.otp_rate_limits.request_count + 1,
        updated_at = v_now
    where bucket_key = p_bucket_key
    returning * into v_bucket;

    return query select true, v_bucket.request_count, 0;
    return;
  end if;

  return query select false, v_bucket.request_count,
    greatest(1, ceil(extract(epoch from
      ((v_bucket.window_started_at + v_window) - v_now)))::integer);
end;
$$;

revoke all on function public.consume_otp_rate_limit(text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_otp_rate_limit(text, integer, integer)
  to service_role;

commit;
