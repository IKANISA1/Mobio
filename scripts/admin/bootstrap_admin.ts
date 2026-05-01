#!/usr/bin/env -S deno run --allow-env --allow-net

import { createClient, type User } from "npm:@supabase/supabase-js@2";

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function optionalEnv(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  return value && value.length > 0 ? value : null;
}

function normalizePhone(value: string): string {
  const digits = value.replace(/\D/g, "");
  if (digits.length < 10) {
    throw new Error("ADMIN_PHONE must contain at least 10 digits.");
  }
  return `+${digits}`;
}

function adminEmailForPhone(phone: string): string {
  return `admin+${phone.replace(/\D/g, "")}@mobi.internal`;
}

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const phone = normalizePhone(requireEnv("ADMIN_PHONE"));
const name = optionalEnv("ADMIN_NAME") ?? "MOBI Admin";
const email = optionalEnv("ADMIN_EMAIL") ?? adminEmailForPhone(phone);
const explicitPassword = optionalEnv("ADMIN_PASSWORD");

const generatedPassword = explicitPassword ??
  `${crypto.randomUUID()}${crypto.randomUUID()}`;

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const { data: usersPage, error: listError } = await supabase.auth.admin
  .listUsers({
    page: 1,
    perPage: 1000,
  });
if (listError) {
  throw listError;
}

let authUser: User | null =
  (usersPage.users ?? []).find((user) =>
    user.phone == phone || user.email?.toLowerCase() == email.toLowerCase()
  ) ?? null;

let created = false;
let rotatedPassword = false;

if (!authUser) {
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    email_confirm: true,
    phone,
    phone_confirm: true,
    password: generatedPassword,
    user_metadata: {
      name,
      phone,
    },
    app_metadata: {
      role: "admin",
      provider: "bootstrap_admin_script",
    },
  });

  if (error || !data.user) {
    throw error ?? new Error("Unable to create admin auth user.");
  }

  authUser = data.user;
  created = true;
  rotatedPassword = true;
} else {
  const payload: Record<string, unknown> = {
    email,
    email_confirm: true,
    phone,
    phone_confirm: true,
    user_metadata: {
      name,
      phone,
    },
    app_metadata: {
      role: "admin",
      provider: "bootstrap_admin_script",
    },
  };

  if (explicitPassword) {
    payload.password = generatedPassword;
    rotatedPassword = true;
  }

  const { data, error } = await supabase.auth.admin.updateUserById(
    authUser.id,
    payload,
  );
  if (error || !data.user) {
    throw error ?? new Error("Unable to update existing admin auth user.");
  }

  authUser = data.user;
}

const { error: profileError } = await supabase.from("profiles").upsert({
  id: authUser.id,
  name,
  phone,
  role: "admin",
  location: null,
  vehicle: null,
  category: null,
  is_driver: false,
  vehicle_type: "cab",
  whatsapp: "",
  country_code: "+250",
  avatar_url: null,
});
if (profileError) {
  throw profileError;
}

console.log(JSON.stringify(
  {
    success: true,
    created,
    rotatedPassword,
    userId: authUser.id,
    email,
    phone,
    name,
    password: rotatedPassword ? "<redacted>" : "<unchanged>",
    passwordSource: rotatedPassword
      ? explicitPassword ? "ADMIN_PASSWORD" : "generated"
      : "unchanged",
    passwordNotice:
      "Password values are never printed. Use WhatsApp OTP admin login or set ADMIN_PASSWORD from a secret manager when password auth is required.",
  },
  null,
  2,
));
