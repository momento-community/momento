# Design Export Context

- Generated at: `2026-05-03T08:51:36.653Z`
- Document ID: `f3eca490-1cd3-4e6f-823e-4764102e25fa`
- Page count: 10

## Original Prompt

```text
# Momentō — FlutterFlow AI Designer Prompt
> Paste this prompt into https://designer.flutterflow.io/dashboard

---

Design a mobile app called **Momentō** (note the macron Ō) — a local event discovery app where events are called **Momentos**. The app helps users find temporary, nearby events happening around them at a time they choose. The domain is [momento.community](http://momento.community). The visual style is inspired by Pinterest: image-first, masonry grid, minimal and sleek — like a clean editorial magazine. White background, olive/sage green accents used sparingly.

---

## BRANDING

- **App name:** Momentō (the Ō has a macron — it is part of the brand)
- **Domain:** [momento.community](http://momento.community)
- **Events called:** Momentos
- **Tagline:** "Find what's happening around you, right now"
- **Background:** `#FFFFFF` (clean white everywhere — no off-white background)
- **Card text section / frames:** `#F1F1EC` (warm off-white — used inside cards and input fields only)
- **Text primary:** `#1A1A1A` (dark charcoal)
- **Text muted:** `#9E9E9E` (timestamps, counts)
- **Primary accent:** `#8A9A5B` (sage green — active nav icon, selected chips, logo colour)
- **Secondary accent:** `#747A5E` (dark olive — category chip backgrounds, secondary labels)
- **Border:** `#E8E8E5` (very subtle — card outlines, dividers)
- **Typography:** Cormorant Garamond (display/titles) + DM Sans (body, labels, buttons, metadata)
- **Logo font:** Josefin Sans Light with wide tracking — MOMENTŌ in all caps, thin weight
- **Icon style:** Lucide Icons, outlined only, always #1A1A1A charcoal (active nav: sage green #8A9A5B)
- **Card style:** 16px rounded corners, 1px #E8E8E5 border, minimal shadow (blur 4px, black 6%)
- **Buttons:** white background + #1A1A1A text + 1px #1A1A1A border, fully rounded (50px) — sleek default. High-emphasis CTA only: #8A9A5B filled, white text. Max one filled button per screen.
- **No emoji anywhere** — Lucide icons only
- **No gradients**
- **Logo:** "MOMENTŌ" wordmark in Josefin Sans Light tracked caps. White on sage green for app icon/splash. Charcoal on white for in-app.

---

## SCREENS TO DESIGN

(see prompt sections 1–8 — same as the master build prompt)
```

## Theme (JSON)

```json
{
  "fonts": {
    "primary": "google:Cormorant Garamond",
    "secondary": "google:DM Sans"
  },
  "colors": {
    "light": {
      "primary": "#8A9A5B",
      "on_primary": "#FFFFFF",
      "secondary": "#747A5E",
      "on_secondary": "#FFFFFF",
      "accent": "#FFD60A",
      "background": "#FFFFFF",
      "surface": "#F1F1EC",
      "on_surface": "#1A1A1A",
      "primary_text": "#1A1A1A",
      "secondary_text": "#9E9E9E",
      "hint": "#E8E8E5",
      "error": "#E63946",
      "on_error": "#FFFFFF",
      "success": "#52B788",
      "divider": "#E8E8E5",
      "transparent": "#00000000"
    },
    "dark": {
      "primary": "#8A9A5B",
      "on_primary": "#FFFFFF",
      "secondary": "#A3AC8A",
      "on_secondary": "#1A1A1A",
      "accent": "#FFD60A",
      "background": "#121212",
      "surface": "#1E1E1B",
      "on_surface": "#F1F1EC",
      "primary_text": "#F1F1EC",
      "secondary_text": "#9E9E9E",
      "hint": "#333333",
      "error": "#FF4D4D",
      "on_error": "#FFFFFF",
      "success": "#52B788",
      "divider": "#2A2A28",
      "transparent": "#00000000"
    }
  },
  "text_styles": {
    "headline_large": { "font": "primary", "size": 34, "weight": 700, "height": 1.1 },
    "headline_medium": { "font": "primary", "size": 28, "weight": 600, "height": 1.2 },
    "title_large": { "font": "primary", "size": 22, "weight": 600, "height": 1.2 },
    "title_medium": { "font": "secondary", "size": 17, "weight": 600, "height": 1.3 },
    "body_large": { "font": "secondary", "size": 16, "weight": 400, "height": 1.5 },
    "body_medium": { "font": "secondary", "size": 14, "weight": 400, "height": 1.4 },
    "body_small": { "font": "secondary", "size": 12, "weight": 400, "height": 1.4 },
    "label_large": { "font": "secondary", "size": 14, "weight": 600, "height": 1.3 },
    "label_medium": { "font": "secondary", "size": 12, "weight": 600, "height": 1.3 },
    "label_small": { "font": "secondary", "size": 11, "weight": 700, "height": 1.2 }
  },
  "spacing": { "xs": 4, "sm": 8, "md": 16, "lg": 24, "xl": 32 },
  "radii":   { "sm": 8, "md": 16, "lg": 24, "full": 9999 },
  "shadows": {
    "sm": { "color": "#0000000F", "dx": 0, "dy": 2, "blur": 4,  "spread": 0 },
    "md": { "color": "#0000001A", "dx": 0, "dy": 4, "blur": 8,  "spread": 0 },
    "lg": { "color": "#00000026", "dx": 0, "dy": 8, "blur": 16, "spread": 0 },
    "xl": { "color": "#00000033", "dx": 0, "dy": 12,"blur": 24, "spread": 0 }
  }
}
```

## Pages

### 1. Discover Home
- **Frame:** `frame1`
- **Intent:** Pinterest-style 2-column masonry feed with editorial wordmark header and central "Now ▾" time-selector pill.
- **Top bar:** glass-blur white bg (80% opacity), MOMENTŌ wordmark left (Josefin 300, label_large), "Now ▾" pill centre (white bg, 1px divider, full radius), tune icon right.
- **Body:** scrollable column, `md` padding, two `Expanded` columns side-by-side with `md` spacing, each holding `@momento_card` widgets at varying image heights (220, 160, 200 / 150, 240, 180).
- **Bottom nav:** white bg, 1px top border, 90px tall, 5 icons row `space_between`: compass (active sage), map outlined, centre Ō badge (48px circle, sage 10% bg, 1px sage border, title_large Josefin 300 sage), add-circle outlined, person outlined.

### 2. Momento Detail View
- **Frame:** `frame2`
- **Intent:** Slide-up scrollable detail with full-width hero image, Cormorant headline, organiser card, action row, and sticky reserve CTA.
- **Hero stack:** 400px image with circular surface back-button top-left, dot carousel indicators bottom-centre (sage 24×4 active, 4×4 white-60% inactive).
- **Content card:** white bg with top-left/right radius 24, `lg` padding, `lg` spacing column. Title (Cormorant 28/600), date row (calendar icon + body_medium), location row (map_pin + body_medium).
- **Organiser block:** surface bg, `lg` radius, `md` padding, row: 40px avatar + name (body_medium 600) + "1.2k followers" (label_small) + outlined "Follow" std.button.
- **Description:** body_medium 1.6 line-height, "Read more" inline (label_large primary 600).
- **Action row:** `space_around` of 5 `@action_icon_button` (favorite_border, visibility, language, ticket, share) — each icon + small label.
- **Related:** "More Momentos near you" label_large + horizontally scrolling row of `@related_momento` cards.
- **Sticky bottom (100px):** glass-blur top border, "Free Entry" + "Registration required" + full-width primary "Reserve Spot" std.button.

### 3. Map Discovery
- **Frame:** `frame3`
- **Intent:** Full-bleed Mapbox-light style map with sage circular markers and floating chrome.
- **Stack contents:** map (lat 52.52, lng 13.405, zoom 14), 5× `@map_marker` at fractional positions.
- **Top floating chrome (180px):** column with `md` spacing — pill search bar (full radius, 48px tall, search icon + "Search location…" + mic icon, md shadow, 1px divider), then row `space_between` of "Filters" pill (sliders icon + label_medium) and a Map/Grid segmented toggle (sage primary on Map, surface inactive on Grid).
- **Bottom floating chrome (220px):** `@compact_momento_card` then 72px floating bottom-nav island (32px radius, xl shadow, 1px divider) holding the 5 nav icons with the centre Ō badge.

### 4. Create a Momento
- **Frame:** `frame4`
- **Intent:** Clean scrollable form with sticky publish CTA.
- **Top bar:** close icon left, "Create a Momentō" Cormorant title_medium 600 centred, 40px spacer right, 1px bottom divider.
- **Form sections** (vertical, 24px gaps): TITLE (`@form_label` + filled textfield, surface bg, radius 12, hint "Give your Momento a name"); CATEGORY (label + horizontally scrollable `@category_chip` row — Art (selected), Music, Food & Drink, Nightlife, Wellness, Markets); WHEN (label + 2×2 grid of surface tiles for Start Date / Time / End Date / Time, each with icon + body_medium label, all `border:divider 1`, then "Max duration: 5 days" label_small); WHERE (label + surface tile with map_pin + "Set location" + chevron_right); DESCRIPTION (filled textfield, 4 max lines, hint "Tell the community what's happening…"); PHOTOS (180px dashed-border surface drop area with add_a_photo icon + body_small "Upload your Momento cover photo").
- **Sticky bottom:** white card with top divider + lg shadow — usage row "3 of 5 free Momentos used" / "60%" + 4px sage progress (value 0.6) + full-width primary "Publish Momentō" std.button.

### 5. My Moments
- **Frame:** `frame5`
- **Intent:** Tabbed list/grid for Organised vs Liked Momentos with bottom nav.
- **Header:** Josefin 300 MOMENTŌ wordmark + Cormorant 600 "My Moments" headline_medium.
- **Tabs row:** "Organised" + "Liked" — active text primary sage + 40×2 sage underline; inactive on_surface + transparent underline. Conditional via `slot:tab` comparison.
- **Organised content** (visible when `tab == organised`): `@momento_list_item` rows for "Rooftop Wine Tasting" (Active sage badge), "Vintage Poster Sale" (Expired hint badge), "Acoustic Garden Set" (Expired). Then surface card empty-state with Lottie "plant growing" + "Ready to host another?" title_medium + outlined "Create New Momento" std.button.
- **Liked content** (visible when `tab == liked`): two-column masonry of `@momento_liked_card` (Neon Night Run, Underground Techno, Pottery Workshop, Local Florist Pop-up) at varying heights.
- **Bottom nav:** same 5-icon pattern, with the centre Ō a *filled* sage circle (white Ō, sm shadow) — denoting this surface as "My Moments" home.

### 6. User Profile
- **Frame:** `frame6`
- **Intent:** Profile header + freemium card + tabbed content + nav.
- **Top bar:** MOMENTŌ wordmark left, settings icon right, 1px bottom divider.
- **Profile section:** centred — 80×80 ring container (2px divider border, 4px padding) wrapping a 72px avatar; Cormorant headline_small bold name "Julianne Vō"; body_small location/bio "Berlin, DE • Curator & Coffee Enthusiast"; stats row `space_evenly` with vertical 1×24 dividers between `@stat_item` (12 Momentos / 482 Liked / 1.2k Followers); outlined small "Edit Profile" std.button.
- **Freemium card:** surface bg, lg radius, lg padding, 1px divider — header row "Free Momentos" (label_medium 600) / "3 of 5 used" (label_small), 8px sage progress (value 0.6), label_small "After 5, each Momento costs €5/day to promote."
- **Tabs:** "My Momentos" (sage active + 40×2 sage underline) / "Liked" (transparent underline).
- **Grid:** two `Expanded` columns of `@profile_momento_card` with status badges — Jazz Vinyl Listening Session (Active), Open Studio Weekend (Expired), Pour Over Masterclass (Active), Rooftop Mixer (Active).
- **Logout:** centred error-coloured underlined label_small.
- **Bottom nav:** standard pattern, person icon active (primary), centre Ō uses 10% sage bg + 1px sage border + on_primary Ō glyph.

### 7. Filter Bottom Sheet
- **Frame:** `frame7`
- **Intent:** Slide-up bottom sheet over scrim.
- **Stack:** full-screen #00000044 scrim + bottom-aligned white sheet (radius top 32, xl shadow, 32px bottom padding).
- **Sheet column** (cross stretch, main min):
  - 40×4 divider drag handle, centred, 12 top / 8 bottom margin.
  - Header row in `lg` horizontal padding: "Filter Momentos" Cormorant title_large 600 + circular surface close icon.
  - Scrollable content column (max-height 550px, `xl` spacing): CATEGORIES `@section_header` + Wrap of 11 `@filter_chip` (Art selected, Food & Drink selected, others unselected). DISTANCE section_header with "12.5 km" trailing value + sage slider (min 0.5, max 50). TIME RANGE section_header + surface lg-radius card with Start Time / arrow_forward / End Time columns (label_small + body_medium 500). SORT BY + 3-pill row (Newest active — surface bg + 1px sage border, Popular and Closest plain).
  - Footer (top divider, lg padding): row of ghost "Reset" std.button (flex 1) + primary large "Apply Filters" std.button (flex 2).

### 8. Splash Screen
- **Frame:** `frame8`
- **Intent:** Sage backdrop + Lottie pulse + Josefin wordmark + tagline + bottom spinner + domain text.
- **Stack:** shaderFill `smokeShade` (primary→secondary→primary, 135°) under everything.
- **Centre column** (`lg` spacing): 120×120 Lottie "minimal elegant pulse" (loop, contain). Below: "MOMENTŌ" headline_large Josefin 300 on_primary; "Find what's happening around you" body_medium DM Sans 300 on_primary 60%, centred.
- **Bottom container** (60px from bottom): circular progress 24×2 on_primary 40% + label_small "momento.community" on_primary 30%.

### 9. Onboarding
- **Frame:** `frame9`
- **Intent:** 3-slide intro with dot indicators + Next / Skip + corner Ō badge + Skip top-right.
- **Stack:** sunsetStipple shader (sage 10% → bg → bg, centred 0.5/0.1).
- **Layout column:** padding 24/32 — MOMENTŌ wordmark Josefin 300 top-left.
- **Expanded centre:** `@onboarding_slide` (img_desc "minimalist urban photography of people walking in a sunny plaza", tagline "AROUND YOU", title "Discover Momentos near you", subtitle "Find temporary, curated events happening in your neighborhood right now.").
- **Bottom block** (40px padding, `xl` spacing): row of 3 `@dot_indicator` (first active sage), then column with primary large full-width "Next" std.button + ghost "Skip" std.button (full width, secondary_text colour).
- **Top-right:** 44×44 circular surface badge (1px divider, sm shadow) with Josefin 300 "Ō" inside (acts as logo mark).

### 10. Authentication
- **Frame:** `frame10`
- **Intent:** Premium login with stacked social buttons.
- **Stack:** sunsetStipple shader (sage 20% → bg → bg, centred 0.5/0.1).
- **Header column** (top 80, sides 40, bottom 40, centred): MOMENTŌ wordmark Josefin 300 size 28; "Find what's happening" Cormorant headline_medium 500 + "around you, right now" Cormorant headline_medium 300 italic, both centred.
- **Hero image card** (240px, 24px sides margin, xl radius, clip, 1px divider): photo "minimalist architectural… sage green plant shadow" + surface 40% blur overlay (backdrop blur 4).
- **Auth column** (32px sides, 60px bottom):
  - "Get started" Cormorant title_large 600 + "Sign in to discover local Momentos" body_medium on_surface (xl bottom margin).
  - `@social_auth_button` Google.
  - 56px on_surface filled button row: white apple icon + "Continue with Apple" body_medium 500 on bg colour, full radius, md bottom margin.
  - `@social_auth_button` Email.
  - lg sizedbox.
  - Centred row "New to the community? Create account" (primary 600 underlined) + label_small "By continuing, you agree to our Terms of Service".
- **Top-left back-arrow** (50/24): arrow_back_ios_new icon button on surface circular bg.

> NOTE: Reusable widgets referenced (`@momento_card`, `@compact_momento_card`, `@map_marker`, `@category_chip`, `@filter_chip`, `@form_label`, `@section_header`, `@stat_item`, `@momento_list_item`, `@momento_liked_card`, `@profile_momento_card`, `@related_momento`, `@onboarding_slide`, `@dot_indicator`, `@social_auth_button`, `@action_icon_button`, `@std.button`, `@std.textfield`) live in `lib/core/widgets/` once the Flutter build begins. Each is a thin Flutter class encoding the spec from its DslDocument usage.
