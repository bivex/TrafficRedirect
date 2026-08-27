# JavaScript Tracker SDK Guide 🌐

The **TrafficRedirect JS Tracker SDK** is a lightweight, zero-dependency, vanilla JavaScript client library for landing pages, pre-landers, and affiliate sites.

---

## 🚀 Quick Integration

Add the tracking script inside the `<head>` or before `</body>` of your landing page:

```html
<script src="//your-tracker-domain.com/campaign_alias?tracker=1" async></script>
```

---

## 🎯 Automatic Features (Zero Code Required)

### 1. Auto CTA Link Rewriter
Any link on your landing page containing:
* `href="{offer}"`
* `href="?return=1"`
* `class="tr-offer"` or `class="k-offer"`
* `data-tr-offer`

Is automatically rewritten upon DOM ready into the proper offer redirect URL containing the visitor's `sub_id`, `token`, and all original `utm_*` tracking tags.

```html
<!-- Automatically rewritten to //your-tracker-domain.com/campaign_alias?return=1&sub_id=...&token=... -->
<a href="{offer}" class="btn-cta">Claim Offer Now!</a>

<!-- Target a specific offer ID -->
<a href="{offer}" data-offer-id="102">Special Bonus Offer</a>
```

### 2. Auto Form Hidden Inputs
The SDK automatically scans all `<form>` elements and injects hidden fields for `sub_id` and `token`:

```html
<form action="/lead_submit.php" method="POST">
  <input type="text" name="name" placeholder="Your Name" />
  <input type="email" name="email" placeholder="Your Email" />
  <!-- Injected automatically by SDK: -->
  <!-- <input type="hidden" name="sub_id" value="1787855074650188872"> -->
  <!-- <input type="hidden" name="token" value="05a1eca669a86c81d8152fe038d1e71a"> -->
  <button type="submit">Submit</button>
</form>
```

### 3. Engagement & Scroll Depth Tracking
The SDK automatically transmits non-blocking beacons via `navigator.sendBeacon`:
* **Pageview Encounter #2:** Triggered on page load with title and referrer.
* **Scroll Depth Beacons:** Triggered at **25%, 50%, 75%, and 100%** scroll depth.

---

## 💻 Programmatic JavaScript API

The SDK exposes `window.TrafficTracker` (and alias `window.KClient`):

```javascript
// 1. Get Click Identifiers
var subId = TrafficTracker.getSubId();
var token = TrafficTracker.getToken();

// 2. Generate Dynamic Offer URL
var offerUrl = TrafficTracker.getOfferUrl({
  offer_id: '105',
  promo_code: 'SUMMER50'
});

// 3. Programmatic Offer Navigation
document.getElementById('buyBtn').addEventListener('click', function() {
  TrafficTracker.goToOffer('105', { source: 'custom_button' });
});

// 4. Client-side Conversion / Postback Trigger
function onFormSuccess() {
  TrafficTracker.postback({
    status: 'lead',
    payout: 35.0,
    currency: 'USD',
    tx_id: 'lead_' + Date.now()
  });
}

// 5. Custom Event Tracking
TrafficTracker.track('video_play', { video_id: 'intro_v2', duration: 120 });
```

---

## 🍪 Storage & Persistence

The SDK persists tracking parameters across navigation and subdomains:
* `localStorage` (Key: `_tr_sub_id`, `_tr_token`)
* `document.cookie` (Path: `/`, `SameSite=Lax`, 30-day lifetime)
