import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { recordEdgeFunctionFailure } from "../_shared/observability.ts";
import { createAdminClient } from "../_shared/supabase.ts";

interface PromoCategory {
  id: string;
  imagePath: string;
  videoPath: string;
  imagePrompts: string[];
  videoPrompts: string[];
}

interface PromoLayoutMetadata {
  focus_x: number;
  focus_y: number;
  safe_text_x: number;
  safe_text_y: number;
}

// 1. Daily Country/City Rotation for Regional Targeting
const AFRICAN_REGIONS = [
  { country: "Rwanda", city: "Kigali" },
  { country: "Kenya", city: "Nairobi" },
  { country: "Uganda", city: "Kampala" },
  { country: "Tanzania", city: "Dar es Salaam" },
  { country: "Nigeria", city: "Lagos" },
  { country: "Ghana", city: "Accra" },
  { country: "South Africa", city: "Cape Town" },
  { country: "Senegal", city: "Dakar" },
  { country: "Democratic Republic of Congo", city: "Kinshasa" },
  { country: "Burundi", city: "Bujumbura" },
];

function getDailyTargetRegion() {
  // Get index based on days since epoch to rotate daily
  const daysSinceEpoch = Math.floor(Date.now() / 86400000);
  return AFRICAN_REGIONS[daysSinceEpoch % AFRICAN_REGIONS.length];
}

// 2. Prompts from Implementation Plan (with placeholders for dynamic injection)
const PROMO_CATEGORIES: PromoCategory[] = [
  {
    id: "nearbyDrivers",
    imagePath: "nearby-drivers/images",
    videoPath: "nearby-drivers/videos",
    imagePrompts: [
      "A breathtakingly beautiful African female influencer standing on a vibrant, neon-lit street in <CITY>, <COUNTRY> at dusk. She is smiling enthusiastically, looking directly into the camera with bright, empathetic eyes. In the background, a cool local moto-taxi driver sits on his bike, wearing a clean helmet. She holds a sleek smartphone showing a dark-mode app. Cinematic, high-fashion street photography, rich colors, deep emotional connection, highly relatable.",
      "A handsome young African man smiling warmly at a moto driver in <COUNTRY>. The passenger is holding up his smartphone to view the driver's profile before agreeing details manually. Both are sharing a genuine, joyful laugh. Warm golden hour lighting, bustling African urban backdrop, highly aspirational, marketing photography, shallow depth of field.",
      "A stunning African fashion model waiting confidently at a modern transit stop in <CITY>. She has flawless glowing skin and a highly relatable, sympathetic smile, looking directly at the viewer. She holds her phone elegantly. The mood is optimistic and premium, suggesting effortless travel. Shot on 85mm lens, beautiful bokeh, vibrant night lights.",
      "Close-up of a charismatic African moto driver in <COUNTRY> taking off his helmet and smiling brilliantly at the camera with extreme warmth and hospitality. The background is a beautifully blurred local street scene. High emotional resonance, suggesting safety, friendliness, and reliable service. Commercial advertisement style.",
    ],
    videoPrompts: [
      "6-second seamless looping video. Realism, cinematic. A breathtakingly beautiful African female influencer on a vibrant street in <CITY>, <COUNTRY> at night. She is looking directly at the camera with a warm, inviting smile, hair gently blowing in the evening breeze. She holds her phone. In the softly blurred background, a friendly moto-taxi driver gives a subtle, reassuring nod. Extremely high emotional connection, aspirated marketing style. Vertical 720x1280. End frame matches start frame.",
      "6-second loop. A handsome African male driver in <COUNTRY> smiling joyfully at the camera. He gently taps his smartphone mounted on his bike, indicating he is ready. Very welcoming, high-trust, authentic human connection. Beautiful bokeh background of moving city lights. Vertical 720x1280.",
    ],
  },
  {
    id: "scheduledTrips",
    imagePath: "scheduled-trips/images",
    videoPath: "scheduled-trips/videos",
    imagePrompts: [
      "A gorgeous, confident young African professional woman in a stylish outfit, sipping premium coffee on a modern balcony overlooking <CITY>, <COUNTRY> at sunrise. She looks at the camera with a brilliant, optimistic smile, holding her smartphone to schedule a ride. Aspirational, lifestyle marketing, bright warm colors, highly relatable.",
      "Two beautiful, trendy African friends (male and female) laughing together in a chic modern cafe in <COUNTRY>. They are looking at a smartphone together, planning a trip. Authentic, joyful expression, showcasing friendship and seamless digital lifestyle. Cinematic lighting, commercial photography.",
      "A stunning group of joyful African young adults dressed up for a night out in <CITY>, taking a selfie while waiting for their ride. Extremely vibrant, energetic, and relatable. Neon lights in the background, high fashion, absolute joy and excitement.",
      "A beautiful African woman with a stylish travel bag standing confidently on a sun-drenched street in <COUNTRY>. She radiates positive energy and readiness, smiling warmly at the camera. Premium travel marketing aesthetic, sunny and aspirational.",
    ],
    videoPrompts: [
      "6-second seamless loop. A gorgeous African woman in elegant professional attire stands in a modern, sunlit room in <CITY>, adjusting her stylish jacket and smiling confidently at the camera. She radiates optimism and readiness for the day. Slow, graceful motion, commercial fashion aesthetic. Vertical 720x1280.",
      "6-second loop. A beautifully dressed African couple holding hands and laughing on a sunny street in <COUNTRY>, looking at their phone together as if watching their scheduled ride arrive. Genuine joy, high emotional resonance. Vertical 720x1280.",
    ],
  },
  {
    id: "nearbyTrips",
    imagePath: "nearby-trips/images",
    videoPath: "nearby-trips/videos",
    imagePrompts: [
      "A beautiful, energetic African girl with a stylish braided hairstyle exploring a colorful, vibrant local market in <CITY>, <COUNTRY>. She turns back to smile directly at the camera with playful, magnetic eyes. High emotional engagement, suggesting authentic local experiences. Bright, saturated colors.",
      "A cool, stylish African guy leaning against a brightly painted wall in <COUNTRY>, casually checking his smartphone. He looks up and gives a relaxed, friendly nod to the camera. Warm, relatable, street-culture aesthetic, suggesting easy mobility around the city.",
      "A gorgeous African woman sitting comfortably in the back of a premium ride, windows down, hair blowing gently in the wind. She looks extremely relaxed and happy, gazing at the vibrant city lights of <CITY>. Aspirational urban lifestyle, deep emotional serenity.",
      "A group of stylish African creatives laughing out loud while walking down a beautiful sunny street in <COUNTRY>. They radiate community and happiness. High-end lifestyle brand photography, extreme relatability.",
    ],
    videoPrompts: [
      "6-second seamless loop. A beautiful, energetic African girl playfully spinning around in a vibrant street art alley in <CITY>, looking directly into the camera with sparking eyes and a huge smile. Represents freedom, discovery, and mobility. Slow motion, highly relatable influencer style. Vertical 720x1280.",
      "6-second loop. A group of stylish African friends taking a video selfie together, laughing and cheering seamlessly. High energy, vibrant colors, celebrating youth and connectivity in <COUNTRY>. Vertical 720x1280.",
    ],
  },
  {
    id: "errorRetry",
    imagePath: "error-retry/images",
    videoPath: "error-retry/videos",
    imagePrompts: [
      "A stunningly beautiful African woman looking directly at the camera with a cute, sympathetic 'oops' expression and a gentle, reassuring smile. She is holding her phone up in a modern setting in <CITY>. The emotion is relatable, forgiving, and encouraging. Soft, beautiful lighting, cinematic portrait.",
    ],
    videoPrompts: [
      "6-second seamless loop. A highly relatable, beautiful African woman looking into the lens with a soft, sympathetic smile and a slight playful shrug, as if saying 'Oops, let's try that again.' She playfully taps her phone screen once. The emotion is incredibly reassuring and warm. Cinematic, soft lighting in <CITY>. Vertical 720x1280.",
      "6-second loop. A cute, expressive African guy looking at the camera with a lighthearted, comedic 'uh-oh' smile, holding his phone up as if looking for a signal. Very endearing and relatable, defusing any user frustration. Vertical 720x1280.",
    ],
  },
];

const PROMO_LAYOUT_DEFAULTS: Record<string, {
  image: PromoLayoutMetadata[];
  video: PromoLayoutMetadata[];
}> = {
  nearbyDrivers: {
    image: [
      { focus_x: 0.76, focus_y: 0.36, safe_text_x: 0.12, safe_text_y: 0.10 },
      { focus_x: 0.72, focus_y: 0.42, safe_text_x: 0.12, safe_text_y: 0.10 },
      { focus_x: 0.74, focus_y: 0.34, safe_text_x: 0.12, safe_text_y: 0.10 },
      { focus_x: 0.68, focus_y: 0.32, safe_text_x: 0.12, safe_text_y: 0.10 },
    ],
    video: [
      { focus_x: 0.74, focus_y: 0.36, safe_text_x: 0.12, safe_text_y: 0.10 },
      { focus_x: 0.70, focus_y: 0.34, safe_text_x: 0.12, safe_text_y: 0.10 },
    ],
  },
  scheduledTrips: {
    image: [
      { focus_x: 0.68, focus_y: 0.32, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.62, focus_y: 0.34, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.66, focus_y: 0.36, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.72, focus_y: 0.40, safe_text_x: 0.12, safe_text_y: 0.12 },
    ],
    video: [
      { focus_x: 0.68, focus_y: 0.34, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.64, focus_y: 0.36, safe_text_x: 0.12, safe_text_y: 0.12 },
    ],
  },
  nearbyTrips: {
    image: [
      { focus_x: 0.72, focus_y: 0.42, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.70, focus_y: 0.40, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.68, focus_y: 0.46, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.64, focus_y: 0.38, safe_text_x: 0.12, safe_text_y: 0.12 },
    ],
    video: [
      { focus_x: 0.72, focus_y: 0.44, safe_text_x: 0.12, safe_text_y: 0.12 },
      { focus_x: 0.66, focus_y: 0.40, safe_text_x: 0.12, safe_text_y: 0.12 },
    ],
  },
  errorRetry: {
    image: [
      { focus_x: 0.60, focus_y: 0.34, safe_text_x: 0.14, safe_text_y: 0.12 },
    ],
    video: [
      { focus_x: 0.60, focus_y: 0.36, safe_text_x: 0.14, safe_text_y: 0.12 },
      { focus_x: 0.62, focus_y: 0.36, safe_text_x: 0.14, safe_text_y: 0.12 },
    ],
  },
};

function layoutMetadataFor(
  categoryId: string,
  type: "image" | "video",
  index: number,
): PromoLayoutMetadata {
  const group = PROMO_LAYOUT_DEFAULTS[categoryId];
  const defaults = type === "video" ? group?.video : group?.image;

  if (!defaults || defaults.length === 0) {
    return {
      focus_x: 0.70,
      focus_y: 0.38,
      safe_text_x: 0.12,
      safe_text_y: 0.12,
    };
  }

  return defaults[Math.min(index, defaults.length - 1)];
}

async function secretDigest(value: string): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return new Uint8Array(digest);
}

function constantTimeEquals(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) {
    return false;
  }

  let diff = 0;
  for (let index = 0; index < left.length; index++) {
    diff |= left[index] ^ right[index];
  }
  return diff === 0;
}

async function isAuthorizedGenerationRequest(req: Request): Promise<boolean> {
  const configuredSecret = Deno.env.get("PROMO_GENERATION_SECRET")?.trim();
  const providedSecret = req.headers.get("x-cron-secret")?.trim();

  if (!configuredSecret || !providedSecret) {
    return false;
  }

  return constantTimeEquals(
    await secretDigest(configuredSecret),
    await secretDigest(providedSecret),
  );
}

function errorSummary(error: unknown): Record<string, string> {
  return {
    name: error instanceof Error ? error.name : typeof error,
    message: error instanceof Error ? error.message.slice(0, 160) : "unknown",
  };
}

async function recordPromoAudit(
  supabaseClient: ReturnType<typeof createAdminClient>,
  action: string,
  details: Record<string, unknown>,
) {
  try {
    const { error } = await supabaseClient.from("admin_audit_log").insert({
      admin_id: null,
      action,
      target_type: "promo_media",
      target_id: null,
      details,
    });
    if (error) throw new Error(error.message);
  } catch (error) {
    console.error(
      "[promo-generation] audit insert failed",
      errorSummary(error),
    );
  }
}

// Standard approach for Gemini/Vertex REST calls natively in Deno
async function generateMediaWithGoogle(
  prompt: string,
  type: "image" | "video",
): Promise<Uint8Array> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ||
    Deno.env.get("GOOGLE_API_KEY");
  if (!apiKey) {
    throw new Error(
      "Missing GEMINI_API_KEY environment variable in Supabase secrets.",
    );
  }

  console.log(`[Google API] Requesting ${type} asset`);

  if (type === "image") {
    // Call Gemini API for Imagen 3
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-001:predict?key=${apiKey}`;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        instances: [{ prompt: prompt }],
        parameters: {
          sampleCount: 1,
          aspectRatio: "9:16", // Vertical images required for our UI
          outputOptions: { mimeType: "image/png" },
        },
      }),
    });

    if (!response.ok) {
      await response.body?.cancel();
      console.error(`[Imagen 3 Error] HTTP ${response.status}`);
      throw new Error(`Imagen 3 API Error: ${response.status}`);
    }

    const data = await response.json();
    if (!data.predictions || data.predictions.length === 0) {
      throw new Error("No predictions returned from Imagen 3 API");
    }

    // Convert returned base64 to byte array
    const base64Image = data.predictions[0].bytesBase64Encoded;
    const binaryString = atob(base64Image);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes;
  } else if (type === "video") {
    throw new Error(
      "Video generation is not enabled yet. Skipping promo video upload.",
    );
  }

  throw new Error(`Invalid media type requested: ${type}`);
}

export async function handleGeneratePromoContent(
  req: Request,
): Promise<Response> {
  const corsResponse = handleCors(req);
  if (corsResponse) {
    return corsResponse;
  }

  if (req.method !== "POST") {
    return methodNotAllowed("POST", req);
  }

  if (!(await isAuthorizedGenerationRequest(req))) {
    return errorResponse("Unauthorized", 401, undefined, req);
  }

  try {
    const supabaseClient = createAdminClient();

    const targetRegion = getDailyTargetRegion();
    let generatedCount = 0;
    let failedCount = 0;
    await recordPromoAudit(supabaseClient, "promo_generation_started", {
      target_region: targetRegion,
      source: "generate-promo-content",
    });
    console.log(
      `Starting promotional asset generation pipeline. Target Region for today: ${targetRegion.city}, ${targetRegion.country}`,
    );

    for (const cat of PROMO_CATEGORIES) {
      console.log(`Processing category: ${cat.id}`);

      // 1. Generate & Upload Images
      for (let i = 0; i < cat.imagePrompts.length; i++) {
        // Inject dynamic region into the prompt
        const prompt = cat.imagePrompts[i]
          .replace(/<CITY>/g, targetRegion.city)
          .replace(/<COUNTRY>/g, targetRegion.country);

        const fileName = `${cat.imagePath}/${i}.png`; // e.g., nearby-drivers/images/0.png
        const metadata = layoutMetadataFor(cat.id, "image", i);

        try {
          const mediaBytes = await generateMediaWithGoogle(prompt, "image");

          const { error: uploadError } = await supabaseClient
            .storage
            .from("promo-media")
            .upload(fileName, mediaBytes, {
              contentType: "image/png",
              upsert: true,
              metadata,
            });
          if (uploadError) throw uploadError;

          generatedCount++;
          console.log(`[SUCCESS] Uploaded ${fileName}`);
        } catch (error) {
          failedCount++;
          console.error(
            `[ERROR] Failed to generate/upload image ${fileName}:`,
            errorSummary(error),
          );
        }
      }

      // 2. Generate & Upload Video (always using the first prompt as the primary)
      if (cat.videoPrompts.length > 0) {
        // Inject dynamic region into the prompt
        const videoPrompt = cat.videoPrompts[0]
          .replace(/<CITY>/g, targetRegion.city)
          .replace(/<COUNTRY>/g, targetRegion.country);

        const fileName = `${cat.videoPath}/0.mp4`;
        const metadata = layoutMetadataFor(cat.id, "video", 0);

        try {
          const mediaBytes = await generateMediaWithGoogle(
            videoPrompt,
            "video",
          );

          const { error: uploadError } = await supabaseClient
            .storage
            .from("promo-media")
            .upload(fileName, mediaBytes, {
              contentType: "video/mp4",
              upsert: true,
              metadata,
            });
          if (uploadError) throw uploadError;

          generatedCount++;
          console.log(`[SUCCESS] Uploaded ${fileName}`);
        } catch (error) {
          failedCount++;
          console.error(
            `[ERROR] Failed to generate/upload video ${fileName}:`,
            errorSummary(error),
          );
        }
      }
    }

    await recordPromoAudit(supabaseClient, "promo_generation_completed", {
      target_region: targetRegion,
      generated_count: generatedCount,
      failed_count: failedCount,
      source: "generate-promo-content",
    });

    return jsonResponse(
      {
        success: generatedCount > 0,
        message: generatedCount > 0
          ? "Generation pipeline completed."
          : "No promotional assets were generated.",
        generatedCount,
        failedCount,
      },
      generatedCount > 0 ? 200 : 502,
      req,
    );
  } catch (error: unknown) {
    console.error("[promo-generation] failed", errorSummary(error));
    try {
      await recordEdgeFunctionFailure(createAdminClient(), {
        functionName: "generate-promo-content",
        error,
      });
    } catch (logError) {
      console.error(
        "[promo-generation] failure logging failed",
        errorSummary(logError),
      );
    }
    return errorResponse(
      "Unable to generate promotional assets",
      500,
      undefined,
      req,
    );
  }
}

if (import.meta.main) {
  Deno.serve(handleGeneratePromoContent);
}
