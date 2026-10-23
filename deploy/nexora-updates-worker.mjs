// Worker independiente: SOLO recursos gestionados por NEXORA.
// Para publicar una nueva base se requiere publicar TAMBIÉN una variante de esa base.
// Ejemplo seguro (archivos de texto internos) para probar detección byte por byte.
const REVISION = 1;
const NOTES = `NEXORA SYSTEM 2026 — Recursos v${REVISION}\nCompatibilidad exacta SHA-256.\n`;
const ORIGINAL = `nexora-config=v${REVISION}\ntheme=red\n`;
const MODIFIED = `nexora-config=v${REVISION}\ntheme=red\nvariant=demo\n`;
const encoder = new TextEncoder();
function hex(bytes) {
  return [...new Uint8Array(bytes)].map(x => x.toString(16).padStart(2, '0')).join('');
}
async function meta(content, url) {
  const bytes = encoder.encode(content);
  return {url, sha256: hex(await crypto.subtle.digest('SHA-256', bytes)), bytes: bytes.length};
}
function response(body, type, status = 200) {
  return new Response(body, { status, headers: {
    'content-type': type, 'cache-control': 'no-store',
    'x-content-type-options': 'nosniff' } });
}
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== 'GET') return response('Method Not Allowed', 'text/plain', 405);
    if (url.pathname === '/manifest.json') {
      const original = await meta(ORIGINAL, '/demo/original.txt');
      const modified = await meta(MODIFIED, '/demo/modified.txt');
      return response(JSON.stringify({ schema: 1,
        resources: [{id:'release-notes', revision: REVISION,
          file:'release-notes.txt', ...await meta(NOTES, '/release-notes.txt')}],
        compatiblePairs: [{id:'nexora-demo', revision:REVISION, original, modified,
          modifiedForOriginalSHA256:original.sha256}]
      }), 'application/json; charset=utf-8');
    }
    if (url.pathname === '/release-notes.txt') return response(NOTES,'text/plain; charset=utf-8');
    if (url.pathname === '/demo/original.txt') return response(ORIGINAL, 'text/plain; charset=utf-8');
    if (url.pathname === '/demo/modified.txt') return response(MODIFIED, 'text/plain; charset=utf-8');
    return response('Not Found', 'text/plain', 404);
  }
};
