// Entry worker for the web PDF viewer.
//
// Strategy:
//   1) Linearized + preferRangeAccess → stock pdfrx Range/206 for page 1
//   2) Non-linearized → full download once into memory (with progress)
// Plaintext PDFs are never written to Cache Storage (revocation / multi-user).
importScripts(new URL('/assets/packages/pdfrx/assets/pdfium_worker.js', self.location.origin).href);

const MAX_PDF_BYTES = 100 * 1024 * 1024;

const loadDocumentFromUrlStock = loadDocumentFromUrl;

functions.loadDocumentFromUrl = async function (params) {
  try {
    return await loadDocumentFromUrlFast(params || {});
  } catch (err) {
    console.warn('PDF fast open failed; falling back to stock download', err);
    return loadDocumentFromUrlStock(params);
  }
};

async function loadDocumentFromUrlFast(params) {
  const preferRangeAccess = !!params.preferRangeAccess;

  // Non-linearized books: one full GET into memory only (no Cache Storage).
  if (!preferRangeAccess) {
    return loadDocumentFromUrlFullInMemory(params);
  }

  return loadDocumentFromUrlStock(params);
}

async function loadDocumentFromUrlFullInMemory(params) {
  const url = params.url;
  const password = params.password || '';
  const useProgressiveLoading = params.useProgressiveLoading || false;
  const headers = stripRangeHeader(params.headers || {});
  const progressCallbackId = params.progressCallbackId;

  const data = await downloadFullPdfBytes(url, headers, progressCallbackId);
  return loadDocumentFromData({
    data: data.buffer,
    password: password,
    useProgressiveLoading: useProgressiveLoading,
  });
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
