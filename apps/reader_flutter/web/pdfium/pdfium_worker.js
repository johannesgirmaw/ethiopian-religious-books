// Entry worker for the web PDF viewer.
//
// Live byte-range GetBlock is too slow for multi-page scanned PDFs and leaves
// page 1 blank while every page's structure is fetched. Instead we:
//   1) open from the Cache API when the book+revision was already downloaded
//   2) otherwise stream the full file once (with progress) via the same-origin
//      /pdf-proxy/ path, verify it, cache it, then open from memory
importScripts(new URL('/assets/packages/pdfrx/assets/pdfium_worker.js', self.location.origin).href);

const PDF_FULL_CACHE = 'fm-pdf-full-v2';
const MAX_PDF_BYTES = 100 * 1024 * 1024;

const loadDocumentFromUrlFull = loadDocumentFromUrl;
functions.loadDocumentFromUrl = async function (params) {
  if (!params || !params.preferRangeAccess) {
    return loadDocumentFromUrlFull(params);
  }
  try {
    return await loadDocumentFromUrlCached(params);
  } catch (err) {
    console.warn('PDF cached open failed; falling back to direct download', err);
    return loadDocumentFromUrlFull(params);
  }
};

async function loadDocumentFromUrlCached(params) {
  const url = params.url;
  const password = params.password || '';
  const useProgressiveLoading = params.useProgressiveLoading || false;
  const headers = params.headers || {};
  const progressCallbackId = params.progressCallbackId;

  const cached = await readFullCache(url);
  if (cached && isValidPdfBytes(cached)) {
    reportPdfProgress(progressCallbackId, cached.byteLength, cached.byteLength);
    return loadDocumentFromData({
      data: cached,
      password: password,
      useProgressiveLoading: useProgressiveLoading,
    });
  }

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

  await writeFullCache(url, data);
  return loadDocumentFromData({
    data: data.buffer,
    password: password,
    useProgressiveLoading: useProgressiveLoading,
  });
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
    // Include query (revision id) so republished books do not reuse a stale blob.
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
