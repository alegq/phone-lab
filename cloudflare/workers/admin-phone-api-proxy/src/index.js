/**
 * Same-origin /api/* proxy for Cloudflare Pages domain.
 *
 * Route: admin-phone.bufsa.com/api/*
 * Forwards to: https://api.admin-phone.bufsa.com/*
 */

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (!url.pathname.startsWith('/api/')) {
      return new Response('not_found', { status: 404 });
    }

    const upstream = new URL(request.url);
    upstream.hostname = 'api.admin-phone.bufsa.com';
    upstream.protocol = 'https:';

    // Preserve method/headers/body; Cloudflare will handle Host/SNI.
    const init = {
      method: request.method,
      headers: request.headers,
      body: ['GET', 'HEAD'].includes(request.method) ? undefined : request.body,
      redirect: 'manual',
    };

    return fetch(upstream.toString(), init);
  },
};

