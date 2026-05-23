/**
 * TOM-PA AI Backend — Cloudflare Worker
 *
 * Endpoints:
 *   GET  /health        → liveness check
 *   POST /chat          → text query with company context
 *   POST /ocr           → image → structured JSON extraction
 *
 * Secrets (set with: wrangler secret put GEMINI_API_KEY)
 *   GEMINI_API_KEY  — Gemini API key, never leaves this Worker
 *   APP_SECRET      — simple shared secret the app sends in Authorization header
 *                     to prevent random internet traffic hitting your endpoint
 *
 * The app sends:   Authorization: Bearer <APP_SECRET>
 */

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';
const MODEL       = 'gemini-2.5-flash-lite';

// ─── Auth middleware ───────────────────────────────────────────────────────

function authorized(request, env) {
  const header = request.headers.get('Authorization') ?? '';
  const token  = header.startsWith('Bearer ') ? header.slice(7) : '';
  return token === env.APP_SECRET;
}

function deny() {
  return new Response(JSON.stringify({ error: 'Unauthorized' }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  });
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ─── /chat ────────────────────────────────────────────────────────────────

const SYSTEM_PROMPT = `
You are a helpful accounting assistant for an Indian SME using the TOM-PA mobile app.
You understand Tally-style double-entry accounting, GST, and basic Indian tax/audit concepts.
Answer questions about the user's own data (provided in context).
Be concise. Give exact figures when known. If a figure isn't in the context, say so — never invent numbers.
Respond in the same language the user writes in (English or Tamil).
`.trim();

async function handleChat(request, env) {
  const { history = [], message, context = '' } = await request.json();
  if (!message) return json({ error: 'message is required' }, 400);

  const contents = [
    { role: 'user',  parts: [{ text: `${SYSTEM_PROMPT}\n\nCompany context:\n${context}` }] },
    { role: 'model', parts: [{ text: 'Understood. Ready to help with your accounts.' }] },
    ...history.map(m => ({ role: m.role, parts: [{ text: m.text }] })),
    { role: 'user',  parts: [{ text: message }] },
  ];

  const res = await fetch(
    `${GEMINI_BASE}/${MODEL}:generateContent?key=${env.GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents,
        generationConfig: { temperature: 0.3, maxOutputTokens: 800 },
      }),
    }
  );
  const data = await res.json();
  if (!res.ok) return json({ error: data }, res.status);
  const reply = data.candidates?.[0]?.content?.parts?.[0]?.text ?? 'No response.';
  return json({ reply });
}

// ─── /ocr ─────────────────────────────────────────────────────────────────

const OCR_PROMPT = `
You are an OCR + data extraction assistant for an Indian SME accounting app.
Given the attached image of a receipt or invoice, extract structured data.
Respond ONLY with valid JSON matching this schema exactly — no markdown, no preamble:
{
  "vendor_name": string | null,
  "vendor_gstin": string | null,
  "invoice_number": string | null,
  "invoice_date": "YYYY-MM-DD" | null,
  "total_amount": number | null,
  "taxable_amount": number | null,
  "cgst_amount": number | null,
  "sgst_amount": number | null,
  "igst_amount": number | null,
  "tax_rate_percent": number | null,
  "items": [{ "description": string, "hsn": string|null, "qty": number|null, "rate": number|null, "amount": number|null }],
  "currency": "INR",
  "confidence": "high" | "medium" | "low",
  "raw_text": string
}
If a field is not visible set it to null. Do not invent values.
`.trim();

async function handleOcr(request, env) {
  const { image_base64, mime_type = 'image/jpeg' } = await request.json();
  if (!image_base64) return json({ error: 'image_base64 is required' }, 400);

  const res = await fetch(
    `${GEMINI_BASE}/${MODEL}:generateContent?key=${env.GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: OCR_PROMPT },
            { inline_data: { mime_type, data: image_base64 } },
          ],
        }],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: 'application/json',
        },
      }),
    }
  );
  const data = await res.json();
  if (!res.ok) return json({ error: data }, res.status);
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? '{}';
  try {
    return json({ extracted: JSON.parse(text) });
  } catch {
    return json({ extracted: null, raw: text });
  }
}

// ─── Router ───────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      });
    }

    // Health — no auth required
    if (url.pathname === '/health' && request.method === 'GET') {
      return json({ status: 'ok', model: MODEL });
    }

    // Auth gate for all other routes
    if (!authorized(request, env)) return deny();

    if (url.pathname === '/chat' && request.method === 'POST')
      return handleChat(request, env);

    if (url.pathname === '/ocr' && request.method === 'POST')
      return handleOcr(request, env);

    return json({ error: 'Not found' }, 404);
  },
};
