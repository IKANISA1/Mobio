import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const appRoot = "apps/momobio_sms_bridge";
const sourceDir =
  `${appRoot}/app/src/main/java/com/momobio/app`;
const failures = [];

function read(path) {
  const fullPath = join(root, path);
  if (!existsSync(fullPath)) {
    failures.push(`missing ${path}`);
    return "";
  }
  return readFileSync(fullPath, "utf8");
}

function sha256(path) {
  const fullPath = join(root, path);
  if (!existsSync(fullPath)) {
    failures.push(`missing ${path}`);
    return "";
  }
  return createHash("sha256").update(readFileSync(fullPath)).digest("hex");
}

if (!existsSync(join(root, appRoot))) {
  failures.push(`missing ${appRoot}`);
}

const gradle = read(`${appRoot}/app/build.gradle.kts`);
const manifest = read(`${appRoot}/app/src/main/AndroidManifest.xml`);
const strings = read(`${appRoot}/app/src/main/res/values/strings.xml`);
const mainActivity = read(`${sourceDir}/MainActivity.kt`);
const receiver = read(`${sourceDir}/SmsReceiver.kt`);
const uploadClient = read(`${sourceDir}/UploadClient.kt`);
const smsReader = read(`${sourceDir}/MomoSms.kt`);
const functionEntry = read("supabase/functions/momobio-sms-ingest/index.ts");

for (const marker of [
  'namespace = "com.momobio.app"',
  'applicationId = "com.momobio.app"',
]) {
  if (!gradle.includes(marker)) failures.push(`Android identity missing ${marker}`);
}

for (const marker of [
  "<string name=\"app_name\">Mo Mobio</string>",
]) {
  if (!strings.includes(marker)) failures.push(`app identity missing ${marker}`);
}

for (const marker of [
  "android.permission.RECEIVE_SMS",
  "android.permission.READ_SMS",
  "android.permission.INTERNET",
  "android.permission.FOREGROUND_SERVICE",
  "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
  "android.permission.RECEIVE_BOOT_COMPLETED",
  "android.provider.Telephony.SMS_RECEIVED",
  "BridgeForegroundService",
  "BridgeBootReceiver",
]) {
  if (!manifest.includes(marker)) failures.push(`manifest missing ${marker}`);
}

for (const marker of [
  "Mo Mobio",
  "mobio_logo_transparent",
  "Status",
  "Enable SMS access",
  "syncAutomatically",
  "readAllSms",
]) {
  if (!mainActivity.includes(marker)) failures.push(`minimal UI missing ${marker}`);
}

for (const forbidden of [
  "Sync now",
  "Diagnostics",
  "Activity Screen",
  "Device ID",
  "Consent",
  "isLikelyMomoSms",
]) {
  if (mainActivity.toLowerCase().includes(forbidden.toLowerCase())) {
    failures.push(`minimal UI contains forbidden concept: ${forbidden}`);
  }
}

if (
  sha256("icon/mobi_logo_transparent.png") !==
    sha256(`${appRoot}/app/src/main/res/drawable-nodpi/mobio_logo_transparent.png`)
) {
  failures.push("bridge logo must match icon/mobi_logo_transparent.png");
}

for (const density of ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]) {
  if (
    sha256(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`) !==
      sha256(`${appRoot}/app/src/main/res/mipmap-${density}/ic_launcher.png`)
  ) {
    failures.push(`bridge launcher icon must match MOBI mipmap-${density}/ic_launcher.png`);
  }
  if (
    sha256(`android/app/src/main/res/drawable-${density}/ic_launcher_foreground.png`) !==
      sha256(`${appRoot}/app/src/main/res/mipmap-${density}/ic_launcher_foreground.png`)
  ) {
    failures.push(`bridge launcher foreground must match MOBI drawable-${density}/ic_launcher_foreground.png`);
  }
}

for (const marker of [
  "getMessagesFromIntent",
  "SmsQueue",
  "UploadClient",
]) {
  if (!receiver.includes(marker)) failures.push(`SMS receiver missing ${marker}`);
}

for (const source of [receiver, smsReader]) {
  for (const forbidden of ["isLikelyMomoSms"]) {
    if (source.includes(forbidden)) {
      failures.push(`device must not filter SMS before upload; found ${forbidden}`);
    }
  }
}

for (const marker of [
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "momobio-sms-ingest",
]) {
  if (!uploadClient.includes(marker)) failures.push(`upload client missing ${marker}`);
}

for (const forbidden of [
  "SUPABASE_SERVICE_ROLE_KEY",
  "OPENAI_API_KEY",
  "MOMO_SMS_BRIDGE_SECRET",
  "SMS_BRIDGE_SECRET",
  "x-mobi-sms-secret",
  "x-sms-bridge-secret",
]) {
  if (uploadClient.includes(forbidden)) {
    failures.push(`bridge app must not contain ${forbidden}`);
  }
}

for (const marker of [
  "rpc_ingest_driver_subscription_momo_sms",
  "driver_subscription_momo_sms_receipts",
  "parseMomoSmsWithOpenAi",
  "messages.slice(0, 50)",
]) {
  if (!functionEntry.includes(marker)) {
    failures.push(`momobio-sms-ingest missing ${marker}`);
  }
}

if (failures.length > 0) {
  console.error("Mo Mobio SMS bridge validation failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("Mo Mobio SMS bridge validation PASS: minimal app, MOBI assets, and MOBI Supabase bridge contract are present.");
