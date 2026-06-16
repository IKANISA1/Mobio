#!/usr/bin/env -S deno run --allow-env --allow-net --allow-read

import { createClient } from "npm:@supabase/supabase-js@2";

type ChargerSeed = {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  connector_types: string[];
  operator_name?: string;
  phone?: string;
  power_kw?: number;
  price_note?: string;
  place_id?: string;
  is_active: boolean;
  source_urls?: string[];
};

const DEFAULT_CATALOG_PATH = "supabase/seed/kigali_ev_chargers.json";
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function argValue(name: string): string | null {
  const prefix = `${name}=`;
  const match = Deno.args.find((arg) => arg.startsWith(prefix));
  return match ? match.slice(prefix.length) : null;
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function optionalString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function validateSeed(row: unknown, index: number): ChargerSeed {
  if (!row || typeof row !== "object" || Array.isArray(row)) {
    throw new Error(`Catalog row ${index + 1} must be an object.`);
  }

  const record = row as Record<string, unknown>;
  const id = optionalString(record.id);
  const name = optionalString(record.name);
  const address = optionalString(record.address);
  const latitude = record.latitude;
  const longitude = record.longitude;
  const connectorTypes = record.connector_types;

  if (!id || !UUID_RE.test(id)) {
    throw new Error(`Catalog row ${index + 1} has an invalid id.`);
  }
  if (!name || name.length < 2) {
    throw new Error(`Catalog row ${index + 1} must include a charger name.`);
  }
  if (!address || address.length < 3) {
    throw new Error(`Catalog row ${index + 1} must include an address.`);
  }
  if (typeof latitude !== "number" || latitude < -90 || latitude > 90) {
    throw new Error(`Catalog row ${index + 1} has invalid latitude.`);
  }
  if (typeof longitude !== "number" || longitude < -180 || longitude > 180) {
    throw new Error(`Catalog row ${index + 1} has invalid longitude.`);
  }
  if (
    !Array.isArray(connectorTypes) ||
    connectorTypes.some((item) => typeof item !== "string" || !item.trim())
  ) {
    throw new Error(
      `Catalog row ${index + 1} must include connector_types strings.`,
    );
  }

  return {
    id,
    name,
    address,
    latitude,
    longitude,
    connector_types: connectorTypes.map((item) => item.trim()),
    operator_name: optionalString(record.operator_name) ?? undefined,
    phone: optionalString(record.phone) ?? undefined,
    power_kw: typeof record.power_kw === "number" ? record.power_kw : undefined,
    price_note: optionalString(record.price_note) ?? undefined,
    place_id: optionalString(record.place_id) ?? undefined,
    is_active: record.is_active !== false,
    source_urls: Array.isArray(record.source_urls)
      ? record.source_urls
        .filter((item): item is string => typeof item === "string")
        .map((item) => item.trim())
        .filter(Boolean)
      : undefined,
  };
}

const apply = Deno.args.includes("--apply");
const catalogPath = argValue("--catalog") ?? DEFAULT_CATALOG_PATH;
const rawCatalog = await Deno.readTextFile(catalogPath);
const parsed = JSON.parse(rawCatalog);
if (!Array.isArray(parsed)) {
  throw new Error("EV charger catalog must be a JSON array.");
}
const catalog = parsed.map(validateSeed);

if (!apply) {
  console.log(JSON.stringify(
    {
      dryRun: true,
      catalogPath,
      rows: catalog.length,
      names: catalog.map((row) => row.name),
      applyCommand:
        "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY, then run: deno run --allow-env --allow-net --allow-read scripts/admin/import_ev_chargers.ts --apply",
    },
    null,
    2,
  ));
  Deno.exit(0);
}

const supabaseUrl = requireEnv("SUPABASE_URL");
const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const { data: organization, error: orgError } = await supabase
  .from("organizations")
  .select("id")
  .eq("slug", "mobi-platform")
  .single();
if (orgError || !organization?.id) {
  throw orgError ?? new Error("Unable to resolve mobi-platform organization.");
}

const payload = catalog.map((row) => ({
  id: row.id,
  organization_id: organization.id,
  name: row.name,
  address: row.address,
  latitude: row.latitude,
  longitude: row.longitude,
  connector_types: row.connector_types,
  operator_name: row.operator_name ?? null,
  phone: row.phone ?? null,
  power_kw: row.power_kw ?? null,
  price_note: row.price_note ?? null,
  place_id: row.place_id ?? null,
  is_active: row.is_active,
  created_by: null,
}));

const { error } = await supabase
  .from("ev_chargers")
  .upsert(payload, { onConflict: "id" });
if (error) {
  throw error;
}

console.log(JSON.stringify(
  {
    success: true,
    catalogPath,
    upserted: payload.length,
    organizationId: organization.id,
  },
  null,
  2,
));
