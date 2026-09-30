# Mobio AI Promotional Prompts

These prompts are used by the `generate-promo-content` Supabase Edge Function to generate the marketing imagery and videos for the application's empty states. 

These prompts record product photography content. UI composition, imagery placement and state treatments must follow the external `revolut-design` skill, with Mobio's own identity and workflows. The prompts do not define a visual system.

**Dynamic Regional Targeting:** The tags `<CITY>` and `<COUNTRY>` are replaced dynamically by the edge function based on a daily rotation (e.g., Kigali, Rwanda -> Nairobi, Kenya).

## 1. Imagen 3 Prompts (Images)

### Category: `nearbyDrivers` (No drivers found / finding a ride)
1. "A breathtakingly beautiful African female influencer standing on a vibrant, neon-lit street in <CITY>, <COUNTRY> at dusk. She is smiling enthusiastically, looking directly into the camera with bright, empathetic eyes. In the background, a cool local moto-taxi driver sits on his bike, wearing a clean helmet. She holds a sleek smartphone showing a dark-mode app. Cinematic, high-fashion street photography, rich colors, deep emotional connection, highly relatable."
2. "A handsome young African man smiling warmly at a moto driver in <COUNTRY>. The passenger is holding up his smartphone to scan the driver's face for a seamless cashless payment. Both are sharing a genuine, joyful laugh. Warm golden hour lighting, bustling African urban backdrop, highly aspirational, marketing photography, shallow depth of field."
3. "A stunning African fashion model waiting confidently at a modern transit stop in <CITY>. She has flawless glowing skin and a highly relatable, sympathetic smile, looking directly at the viewer. She holds her phone elegantly. The mood is optimistic and premium, suggesting effortless travel. Shot on 85mm lens, beautiful bokeh, vibrant night lights."
4. "Close-up of a charismatic African moto driver in <COUNTRY> taking off his helmet and smiling brilliantly at the camera with extreme warmth and hospitality. The background is a beautifully blurred local street scene. High emotional resonance, suggesting safety, friendliness, and reliable service. Commercial advertisement style."

### Category: `scheduledTrips` (No scheduled trips)
1. "A gorgeous, confident young African professional woman in a stylish outfit, sipping premium coffee on a modern balcony overlooking <CITY>, <COUNTRY> at sunrise. She looks at the camera with a brilliant, optimistic smile, holding her smartphone to schedule a ride. Aspirational, lifestyle marketing, bright warm colors, highly relatable."
2. "Two beautiful, trendy African friends (male and female) laughing together in a chic modern cafe in <COUNTRY>. They are looking at a smartphone together, planning a trip. Authentic, joyful expression, showcasing friendship and seamless digital lifestyle. Cinematic lighting, commercial photography."
3. "A stunning group of joyful African young adults dressed up for a night out in <CITY>, taking a selfie while waiting for their ride. Extremely vibrant, energetic, and relatable. Neon lights in the background, high fashion, absolute joy and excitement."
4. "A beautiful African woman with a stylish travel bag standing confidently on a sun-drenched street in <COUNTRY>. She radiates positive energy and readiness, smiling warmly at the camera. Premium travel marketing aesthetic, sunny and aspirational."

### Category: `nearbyTrips` (No nearby trips)
1. "A beautiful, energetic African girl with a stylish braided hairstyle exploring a colorful, vibrant local market in <CITY>, <COUNTRY>. She turns back to smile directly at the camera with playful, magnetic eyes. High emotional engagement, suggesting authentic local experiences. Bright, saturated colors."
2. "A cool, stylish African guy leaning against a brightly painted wall in <COUNTRY>, casually checking his smartphone. He looks up and gives a relaxed, friendly nod to the camera. Warm, relatable, street-culture aesthetic, suggesting easy mobility around the city."
3. "A gorgeous African woman sitting comfortably in the back of a premium ride, windows down, hair blowing gently in the wind. She looks extremely relaxed and happy, gazing at the vibrant city lights of <CITY>. Aspirational urban lifestyle, deep emotional serenity."
4. "A group of stylish African creatives laughing out loud while walking down a beautiful sunny street in <COUNTRY>. They radiate community and happiness. High-end lifestyle brand photography, extreme relatability."

### Category: `errorRetry` (Network issues)
1. "A stunningly beautiful African woman looking directly at the camera with a cute, sympathetic 'oops' expression and a gentle, reassuring smile. She is holding her phone up in a modern setting in <CITY>. The emotion is relatable, forgiving, and encouraging. Soft, beautiful lighting, cinematic portrait."


## 2. Veo 3 Prompts (Silent Video Loops)

Videos are 6-second vertical loops (720x1280). They play automatically inside the empty state containers.

### Video: `nearby_drivers`
- **Primary:** "6-second seamless looping video. Realism, cinematic. A breathtakingly beautiful African female influencer on a vibrant street in <CITY>, <COUNTRY> at night. She is looking directly at the camera with a warm, inviting smile, hair gently blowing in the evening breeze. She holds her phone. In the softly blurred background, a friendly moto-taxi driver gives a subtle, reassuring nod. Extremely high emotional connection, aspirated marketing style. Vertical 720x1280. End frame matches start frame."
- **Alternative:** "6-second loop. A handsome African male driver in <COUNTRY> smiling joyfully at the camera. He gently taps his smartphone mounted on his bike, indicating he is ready. Very welcoming, high-trust, authentic human connection. Beautiful bokeh background of moving city lights. Vertical 720x1280."

### Video: `scheduled_trips`
- **Primary:** "6-second seamless loop. A gorgeous African woman in elegant professional attire stands in a modern, sunlit room in <CITY>, adjusting her stylish jacket and smiling confidently at the camera. She radiates optimism and readiness for the day. Slow, graceful motion, commercial fashion aesthetic. Vertical 720x1280."
- **Alternative:** "6-second loop. A beautifully dressed African couple holding hands and laughing on a sunny street in <COUNTRY>, looking at their phone together as if watching their scheduled ride arrive. Genuine joy, high emotional resonance. Vertical 720x1280."

### Video: `nearby_trips`
- **Primary:** "6-second seamless loop. A beautiful, energetic African girl playfully spinning around in a vibrant street art alley in <CITY>, looking directly into the camera with sparking eyes and a huge smile. Represents freedom, discovery, and mobility. Slow motion, highly relatable influencer style. Vertical 720x1280."
- **Alternative:** "6-second loop. A group of stylish African friends taking a video selfie together, laughing and cheering seamlessly. High energy, vibrant colors, celebrating youth and connectivity in <COUNTRY>. Vertical 720x1280."

### Video: `error_retry`
- **Primary:** "6-second seamless loop. A highly relatable, beautiful African woman looking into the lens with a soft, sympathetic smile and a slight playful shrug, as if saying 'Oops, let's try that again.' She playfully taps her phone screen once. The emotion is incredibly reassuring and warm. Cinematic, soft lighting in <CITY>. Vertical 720x1280."
- **Alternative:** "6-second loop. A cute, expressive African guy looking at the camera with a lighthearted, comedic 'uh-oh' smile, holding his phone up as if looking for a signal. Very endearing and relatable, defusing any user frustration. Vertical 720x1280."
