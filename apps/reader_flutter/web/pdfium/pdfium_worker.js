// Entry worker for the web PDF viewer.
//
// Live byte-range GetBlock is too slow for multi-page scanned PDFs and leaves
// page 1 blank while every page's structure is fetched. Instead we:
//   1) open from the Cache API when the book was already downloaded
//   2) otherwise stream the full file once (with progress) via the same-origin
//      /pdf-proxy/ path, cache it, then open from memory
importScripts(new URL('/assets/packages/pdfrx/assets/pdfium_worker.js', self.location.origin).href);

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
  if (cached && cached.byteLength > 8) {
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
    credentials: 'same-origin',
    mode: 'cors',
  });
  if (!response.ok) {
    throw new Error('Failed to download PDF file: ' + response.status + ' ' + response.statusText);
  }

  const total = parseInt(response.headers.get('content-length') || '0', 10);
  let data;
  if (response.body && typeof response.body.getReader === 'function') {
    const reader = response.body.getReader();
    const chunks = [];
    let received = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      received += value.length;
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
    reportPdfProgress(progressCallbackId, data.byteLength, data.byteLength);
  }

  if (data.byteLength < 8) {
    throw new Error('Empty PDF download');
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

function fullCacheKey(url) {
  try {
    const path = new URL(url, self.location.origin).pathname;
    return 'https://fm-pdf-full.local' + path;
  } catch (_) {
    return 'https://fm-pdf-full.local/pdf';
  }
}

async function readFullCache(url) {
  try {
    const cache = await caches.open('fm-pdf-full-v1');
    const res = await cache.match(fullCacheKey(url));
    if (!res) return null;
    return await res.arrayBuffer();
  } catch (_) {
    return null;
  }
}

async function writeFullCache(url, bytes) {
  try {
    const cache = await caches.open('fm-pdf-full-v1');
    const copy = bytes instanceof ArrayBuffer ? bytes.slice(0) : bytes.slice().buffer;
    await cache.put(fullCacheKey(url), new Response(copy, {
      headers: { 'Content-Type': 'application/pdf' },
    }));
  } catch (_) {}
}
