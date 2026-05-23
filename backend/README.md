# TOM-PA AI Backend

Cloudflare Worker that proxies OCR + Chat requests from the TOM-PA app to Gemini.
Your Gemini API key never leaves Cloudflare — it lives in encrypted CF Secrets.

## Deploy in 3 commands

```bash
npm install          # installs wrangler CLI
wrangler secret put GEMINI_API_KEY   # paste your Gemini key when prompted
wrangler secret put APP_SECRET       # paste any random password (e.g. output of: openssl rand -hex 16)
wrangler deploy                      # deploys to *.workers.dev — takes ~10 seconds
```

wrangler deploy gives you a URL like: https://tompa-ai.<your-account>.workers.dev

## Enter that URL in the app

Open TOM-PA → Utility → AI Settings → paste the URL → Save → Test connection.

## Endpoints

| Method | Path     | Auth    | Description                         |
|--------|----------|---------|-------------------------------------|
| GET    | /health  | None    | Returns { status: "ok" }            |
| POST   | /chat    | Bearer  | Accounting assistant with context   |
| POST   | /ocr     | Bearer  | Receipt image → structured JSON     |

## Free tier limits

Cloudflare Workers free tier: 100,000 requests per day. 
An SME doing 200 queries/day uses 0.2% of the limit.
