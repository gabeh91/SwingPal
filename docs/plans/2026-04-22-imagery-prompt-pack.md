# SwingPal Imagery Prompt Pack

Purpose: image-generation prompts for premium in-app scenic/editorial imagery that supports the current SwingPal UI direction.

Use these prompts to generate source imagery for:
- `Home`
- `Round setup`
- `Course detail`
- `Social spotlight`
- optional premium/editorial inserts

These are not meant for the live-round map itself. `Live Round` should remain map/GPS-first.

## Global Art Direction

Core look:
- premium golf lifestyle
- calm, natural, bright
- editorial rather than “sports app promo”
- grounded realism with polished color grading
- no neon, no purple bias, no overly synthetic CGI look

Palette guidance:
- deep pine greens
- sand / cream highlights
- misty off-whites
- warm early-morning or late-afternoon sunlight
- restrained gold accents where natural

Composition rules:
- leave clean negative space for UI overlays
- avoid placing the main subject under likely text regions
- prefer one clear focal subject
- keep backgrounds readable and not too noisy
- avoid busy clubhouses, signage clutter, large crowds, or hard shadows across the subject

Rendering rules:
- realistic photography style
- high dynamic range
- soft vignette only if natural
- detailed but not hyper-sharpened
- no embedded text, no logos, no watermarks
- no obvious brand marks on apparel or bags

People rules:
- natural golf posture
- premium but believable styling
- no exaggerated smiles or ad-like posing
- no uncanny hands or clubs

Recommended master asset size:
- `2048 x 1536` minimum for card/stage imagery
- generate larger if available, but keep composition compatible with cropping

## Suggested Filenames

Use these exact filenames so I can wire them into the app cleanly later:

- `home-lead-stage-v1.jpg`
- `round-discovery-stage-v1.jpg`
- `course-detail-stage-v1.jpg`
- `social-spotlight-stage-v1.jpg`
- `profile-bag-stage-v1.jpg`
- `premium-coaching-stage-v1.jpg`

If you generate multiple variants, keep the same base name and increment:

- `home-lead-stage-v2.jpg`
- `round-discovery-stage-v2.jpg`
- `course-detail-stage-v2.jpg`

Recommended local folder:

- `SwingPal/Assets.xcassets/Generated/`

If you prefer to keep them outside the asset catalog first, use:

- `docs/design/generated-imagery/`

Safe crop guidance:
- assume the app may crop to:
  - `4:3`
  - `3:2`
  - a shallow wide crop for scenic stage headers
- keep the primary focal point within the central `60%` of the image
- keep top-left and lower-left reasonably usable for UI text overlays

Negative prompt guidance:
- low-resolution
- cartoon
- illustration
- extreme HDR
- oversaturated grass
- purple lighting
- artificial lens flare
- text overlay
- watermark
- deformed hands
- duplicate clubs
- floating objects
- distorted horizon

## 1. Home Lead Stage

Use for:
- the top `Home` lead card scenic cover

Preferred filename:
- `home-lead-stage-v1.jpg`

Intent:
- this should feel like the emotional “open the app and go play” image
- calm confidence, not action chaos

Dimensions:
- generate at `2048 x 1536`

Prompt:

```text
Premium editorial golf photography, early morning on an elite coastal golf course, one golfer preparing to start a round on the first tee, calm posture with club grounded and body angled slightly away from camera, lush but natural pine and fairway greens, soft misty light, warm sun touching the grass, elegant depth, cinematic but realistic, clean negative space in the upper-left and lower-left for UI overlay, refined color grading with deep pine, sand, cream, and mist tones, no clubhouse clutter, no brand logos, no text, no watermark, no exaggerated sports-ad energy, high-fidelity realistic photography
```

Focus/state:
- pre-round anticipation
- golfer is about to begin, not mid-swing

Avoid:
- centered close-up portrait
- dramatic follow-through action
- large crowds
- overly dark sky

## 2. Nearby Courses / Round Setup Stage

Use for:
- `CourseListView` scenic stage

Preferred filename:
- `round-discovery-stage-v1.jpg`

Intent:
- should feel like a destination decision
- the user is choosing where to play next

Dimensions:
- generate at `2048 x 1536`

Prompt:

```text
High-end golf destination photography, elevated view across a premium golf course with sculpted fairways, bunkers, and greens, bright natural daylight with soft atmospheric haze, calm editorial composition, one subtle golfer or golf cart in the distance for scale, course textures clearly readable but not busy, elegant negative space for interface overlays, premium natural palette of pine green, sage, sand, and warm off-white, realistic photography, no text, no logos, no watermark
```

Focus/state:
- course selection
- “where should I play?”

Avoid:
- drone view so high that the image becomes map-like
- heavy cloud drama
- tournament crowds

## 3. Course Detail Commitment Stage

Use for:
- `CourseDetailView` scenic top stage

Preferred filename:
- `course-detail-stage-v1.jpg`

Intent:
- the user has chosen a course and is now locking into tee selection
- image should feel specific, confident, and slightly more intimate than the discovery image

Dimensions:
- generate at `2048 x 1536`

Prompt:

```text
Premium realistic golf course photography focused on one signature hole, refined viewpoint showing tee box, fairway shape, green contour, and a few elegant bunkers, soft directional sunlight, composed like an editorial feature image, natural depth, polished but believable color grading, quiet atmosphere, no logos, no signage clutter, no text, no watermark, clean space for overlay panels
```

Focus/state:
- commitment
- “this is the course, now pick the right tees”

Avoid:
- generic grass texture with no hole identity
- flat midday light

## 4. Social Spotlight Cover

Use for:
- `Social` spotlight feature

Preferred filename:
- `social-spotlight-stage-v1.jpg`

Intent:
- editorial round recap
- should feel like a featured story image, not a utility card

Dimensions:
- generate at `2048 x 1536`

Prompt:

```text
Editorial golf lifestyle photography for a featured round recap, premium golfer walking off a green or along a fairway after a strong hole, composed storytelling image with elegant landscape context, soft cinematic sunlight, subtle emotion and momentum, realistic photography, rich but restrained pine and sand palette, high-end sports editorial feel without looking like an advertisement, no logos, no text, no watermark
```

Focus/state:
- completed-round mood
- reflective success or tension after play

Avoid:
- trophy pose
- fist pumps
- obvious staged marketing smile

## 5. Profile / Bag Lifestyle Insert

Use for:
- optional bag/profile section or future premium/profile editorial blocks

Preferred filename:
- `profile-bag-stage-v1.jpg`

Intent:
- clubs, tools, and personal golf setup

Dimensions:
- generate at `1600 x 1200` or larger

Prompt:

```text
Premium golf equipment lifestyle photography, elegant golf bag with a refined set of clubs beside a clean green fairway edge, soft morning light, premium materials visible, realistic textures, composed editorial still life, restrained natural palette of pine, cream, sand, and graphite tones, no visible branding, no text, no watermark
```

Focus/state:
- personal setup
- calm preparedness

Avoid:
- product-catalog white background
- overly commercial studio lighting

## 6. Premium Intelligence / Coaching Insert

Use for:
- optional premium upsell panel or future AI/coaching editorial module

Preferred filename:
- `premium-coaching-stage-v1.jpg`

Intent:
- should suggest intelligence and refinement without looking like sci-fi

Dimensions:
- generate at `1600 x 1200` or larger

Prompt:

```text
Premium editorial golf scene with a golfer studying a shot calmly from the fairway, thoughtful posture, subtle environmental depth, refined natural lighting, realistic course textures, elegant composition with clear negative space for interface overlay, visually suggests strategy and confidence rather than technology overload, pine green, sand, mist, and warm neutral palette, no HUD graphics baked into image, no text, no watermark
```

Focus/state:
- decision-making
- thoughtful shot planning

Avoid:
- holograms
- fake AI overlays
- futuristic screens inside the image

## Image QA Checklist

Before using any generated image, reject it if:
- the focal point sits exactly where text/buttons need to go
- the image is too dark for light-mode overlays
- the grass tone is neon or artificial
- the subject looks posed like an ad campaign instead of a premium editorial shot
- the image has distracting logos, signage, or unusable background clutter
- the club, hands, horizon, or body proportions look even slightly broken

## Implementation Notes

When importing assets into the app:
- prefer subtle gradient overlays in code, not baked into the image
- keep one image family per screen role, not one image reused everywhere
- test each image in both `light` and `dark` mode
- verify the image still reads behind frosted or matte overlay components
- preserve the filenames above so code references stay stable
