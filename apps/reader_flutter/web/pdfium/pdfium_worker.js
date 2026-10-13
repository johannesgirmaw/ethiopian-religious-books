// Entry worker for the web PDF viewer.
//
// Strategy:
//   1) Cache API hit → open from memory (instant reopen)
//   2) Linearized + preferRangeAccess → stock pdfrx Range/206 for page 1,
//      then delayed background full GET into Cache API
//   3) Non-linearized → full download once (with progress) + Cache API
//      (avoids blank page 1 on scanned books under live GetBlock)
importScripts(new URL('/assets/packages/pdfrx/assets/pdfium_worker.js', self.location.origin).href);

const PDF_FULL_CACHE = 'fm-pdf-full-v2';
const MAX_PDF_BYTES = 100 * 1024 * 1024;
/** Delay so Range fetches for page 1 are not starved by a competing full GET. */
const BACKGROUND_CACHE_DELAY_MS = 4000;

const loadDocumentFromUrlStock = loadDocumentFromUrl;
/** @type {Map<string, Promise<void>>} */
const backgroundCacheInflight = new Map();

functions.loadDocumentFromUrl = async function (params) {
  try {
    return await loadDocumentFromUrlFast(params || {});
  } catch (err) {
    console.warn('PDF fast open failed; falling back to stock download', err);
    return loadDocumentFromUrlStock(params);
  }
};

async function loadDocumentFromUrlFast(params) {
  const url = params.url;
  const password = params.password || '';
  const useProgressiveLoading = params.useProgressiveLoading || false;
  const headers = params.headers || {};
  const progressCallbackId = params.progressCallbackId;
  const preferRangeAccess = !!params.preferRangeAccess;

  const cached = await readFullCache(url);
  if (cached && isValidPdfBytes(cached)) {
    reportPdfProgress(progressCallbackId, cached.byteLength, cached.byteLength);
    return loadDocumentFromData({
      data: cached,
      password: password,
      useProgressiveLoading: useProgressiveLoading,
    });
  }

  if (!preferRangeAccess) {
    // Proven path for scanned / non-linearized PDFs: one full GET, then memory open.
    return loadDocumentFromUrlFullCached(params);
  }

  const doc = await loadDocumentFromUrlStock(params);
  scheduleBackgroundFullCache(url, headers);
  return doc;
}

async function loadDocumentFromUrlFullCached(params) {
  const url = params.url;
  const password = params.password || '';
  const useProgressiveLoading = params.useProgressiveLoading || false;
  const headers = stripRangeHeader(params.headers || {});
  const progressCallbackId = params.progressCallbackId;

  const data = await downloadFullPdfBytes(url, headers, progressCallbackId);
  await writeFullCache(url, data);
  return loadDocumentFromData({
    data: data.buffer,
    password: password,
    useProgressiveLoading: useProgressiveLoading,
  });
}

function scheduleBackgroundFullCache(url, headers) {
  const key = fullCacheKey(url);
  if (backgroundCacheInflight.has(key)) return;

  const job = (async () => {
    await sleep(BACKGROUND_CACHE_DELAY_MS);
    const existing = await readFullCache(url);
    if (existing && isValidPdfBytes(existing)) return;
    await downloadAndCacheFull(url, stripRangeHeader(headers || {}));
  })()
    .catch((err) => {
      console.warn('PDF background cache failed', err);
    })
    .finally(() => {
      backgroundCacheInflight.delete(key);
    });

  backgroundCacheInflight.set(key, job);
}

async function downloadAndCacheFull(url, headers) {
  const data = await downloadFullPdfBytes(url, headers, null);
  await writeFullCache(url, data);
}

/**
 * @param {string} url
 * @param {Object.<string, string>} headers
 * @param {number|null|undefined} progressCallbackId
 * @returns {Promise<Uint8Array>}
 */
async function downloadFullPdfBytes(url, headers, progressCallbackId) {
  const response = await fetch(url, {
    method: 'GET',
    headers: headers,
    credentials: 'omit',
    mode: 'cors',
    cache: 'no-store',
  });
  if (!response.ok) {
    throw new Error('Failed to download PDF file: ' + response.status + ' ' + response.statusText);
  }

  const total = parseInt(response.headers.get('content-length') || '0', 10);
  if (total > MAX_PDF_BYTES) {
    throw new Error('PDF exceeds maximum allowed size');
  }

  let data;
  if (response.body && typeof response.body.getReader === 'function') {
    const reader = response.body.getReader();
    const chunks = [];
    let received = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.length;
      if (received > MAX_PDF_BYTES) {
        throw new Error('PDF exceeds maximum allowed size');
      }
      chunks.push(value);
      reportPdfProgress(progressCallbackId, received, total > 0 ? total : received);
    }
    data = new Uint8Array(received);
    let offset = 0;
    for (const chunk of chunks) {
      data.set(chunk, offset);
      offset += chunk.length;
    }
  } else {
    data = new Uint8Array(await response.arrayBuffer());
    if (data.byteLength > MAX_PDF_BYTES) {
      throw new Error('PDF exceeds maximum allowed size');
    }
    reportPdfProgress(progressCallbackId, data.byteLength, data.byteLength);
  }

  if (!isValidPdfBytes(data)) {
    throw new Error('Downloaded file is not a valid PDF');
  }
  if (total > 0 && data.byteLength !== total) {
    throw new Error('Incomplete PDF download');
  }
  return data;
}

function stripRangeHeader(headers) {
  const out = {};
  for (const key of Object.keys(headers || {})) {
    if (key.toLowerCase() === 'range' || key.toLowerCase() === 'if-range') continue;
    out[key] = headers[key];
  }
  return out;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function reportPdfProgress(callbackId, downloaded, total) {
  if (!callbackId) return;
  invokeCallback(callbackId, downloaded, total);
}

function isValidPdfBytes(bytes) {
  if (!bytes || bytes.byteLength < 8) return false;
  const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  return (
    view[0] === 0x25 && // %
    view[1] === 0x50 && // P
    view[2] === 0x44 && // D
    view[3] === 0x46 && // F
    view[4] === 0x2d // -
  );
}

function fullCacheKey(url) {
  try {
    const u = new URL(url, self.location.origin);
    return 'https://fm-pdf-full.local' + u.pathname + u.search;
  } catch (_) {
    return 'https://fm-pdf-full.local/pdf';
  }
}

async function readFullCache(url) {
  try {
    const cache = await caches.open(PDF_FULL_CACHE);
    const res = await cache.match(fullCacheKey(url));
    if (!res) return null;
    const buf = await res.arrayBuffer();
    if (!isValidPdfBytes(buf)) {
      await cache.delete(fullCacheKey(url));
      return null;
    }
    return buf;
  } catch (_) {
    return null;
  }
}

async function writeFullCache(url, bytes) {
  try {
    const cache = await caches.open(PDF_FULL_CACHE);
    const copy = bytes instanceof ArrayBuffer ? bytes.slice(0) : bytes.slice().buffer;
    await cache.put(
      fullCacheKey(url),
      new Response(copy, {
        headers: {
          'Content-Type': 'application/pdf',
          'Cache-Control': 'private, no-store',
        },
      }),
    );
  } catch (_) {}
}
