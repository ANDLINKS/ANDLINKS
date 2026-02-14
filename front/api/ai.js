// Vercel serverless function that securely proxies AI requests.
// Keeps upstream API key on the server side.
module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.API_KEY || '';
  const backendUrl = process.env.AI_BACKEND_URL || '';
  if (!apiKey || !backendUrl) {
    return res.status(503).json({
      error: 'Server is not configured: API_KEY or AI_BACKEND_URL is missing',
    });
  }

  const body = req.body || {};
  const incomingMessages = Array.isArray(body.messages) ? body.messages : [];
  const filteredMessages = incomingMessages
    .map((m) => ({
      role: typeof m?.role === 'string' ? m.role : '',
      content: typeof m?.content === 'string' ? m.content : '',
    }))
    .filter(
      (m) =>
        ['system', 'user', 'assistant', 'tool'].includes(m.role) &&
        m.content.trim().length > 0
    );

  if (filteredMessages.length === 0) {
    return res.status(400).json({ error: 'messages array cannot be empty' });
  }

  try {
    const upstream = await fetch(`${backendUrl.replace(/\/$/, '')}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: JSON.stringify({
        messages: filteredMessages,
        stream: false,
      }),
    });

    const raw = await upstream.text();
    if (!upstream.ok) {
      return res.status(upstream.status).json({
        error: 'AI upstream request failed',
        detail: raw.slice(0, 500),
      });
    }

    // AI backend returns NDJSON. Extract final response.
    let finalResponse = '';
    const lines = raw
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean);

    for (const line of lines) {
      try {
        const parsed = JSON.parse(line);
        if (typeof parsed.response === 'string' && parsed.response.trim()) {
          finalResponse = parsed.response;
        } else if (
          typeof parsed.token === 'string' &&
          !finalResponse
        ) {
          finalResponse += parsed.token;
        }
      } catch (_) {
        // Skip malformed chunks
      }
    }

    if (!finalResponse.trim()) {
      return res.status(502).json({ error: 'AI response was empty' });
    }

    return res.status(200).json({ response: finalResponse });
  } catch (error) {
    return res.status(502).json({
      error: 'Failed to reach AI backend',
      detail: String(error),
    });
  }
};
