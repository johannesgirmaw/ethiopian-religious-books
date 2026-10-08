// Entry worker for the web PDF viewer.
//
// pdfrx's stock worker downloads the entire file before the first page can
// paint. This wrapper keeps that path as a fallback and, when the viewer asks
// for range access, lets pdfium read only the blocks it needs.
importScripts(new URL('/assets/packages/pdfrx/assets/pdfium_worker.js', self.location.origin).href);

const loadDocumentFromUrlFull = loadDocumentFromUrl;
functions.loadDocumentFromUrl = async function (params) {
  if (!params || !params.preferRangeAccess) {
    return loadDocumentFromUrlFull(params);
  }
  return loadDocumentFromUrlByRange(params);
};

const PDF_BLOCK_BYTES = 512 * 1024;

async function loadDocumentFromUrlByRange(params) {
  const url = params.url;
  const password = params.password || '';
  const useProgressiveLoading = params.useProgressiveLoading || false;
  const headers = params.headers || {};
  const progressCallbackId = params.progressCallbackId;

  if (typeof Pdfium.wasmExports.FPDF_LoadCustomDocument !== 'function') {
    return loadDocumentFromUrlFull(params);
  }

  const blocks = new Map();
  await restorePdfBlocks(url, blocks);
  const probe = syncFetchRange(url, headers, 0, PDF_BLOCK_BYTES - 1);
  if (!probe.supportsRange || !probe.fileSize) {
    if (probe.bytes && probe.bytes.length > 8) {
      const copy = probe.bytes.slice();
      return loadDocumentFromData({
        data: copy.buffer,
        password: password,
        useProgressiveLoading: useProgressiveLoading,
      });
    }
    return loadDocumentFromUrlFull(params);
  }

  const fileSize = probe.fileSize;
  if (isCompleteBlock(probe.bytes, 0, fileSize)) {
    blocks.set(0, probe.bytes);
    rememberPdfBlock(url, 0, probe.bytes.length - 1, probe.bytes);
  }
  reportPdfProgress(progressCallbackId, bytesHeld(blocks), fileSize);

  const getBlock = (param, position, pBuf, size) => {
    try {
      let remaining = size;
      let pos = position;
      let dst = pBuf;
      while (remaining > 0 && pos < fileSize) {
        const blockId = Math.floor(pos / PDF_BLOCK_BYTES);
        const block = ensurePdfBlock(url, headers, blocks, fileSize, blockId, progressCallbackId);
        if (!block) return 0;
        const offset = pos - blockId * PDF_BLOCK_BYTES;
        const n = Math.min(remaining, block.length - offset, fileSize - pos);
        if (n <= 0) return 0;
        new Uint8Array(Pdfium.memory.buffer, dst, n).set(block.subarray(offset, offset + n));
        remaining -= n;
        pos += n;
        dst += n;
      }
      return 1;
    } catch (err) {
      console.error('PDF range read failed', err);
      return 0;
    }
  };

  let callbackIndex = 0;
  let fileAccessPtr = 0;
  const cleanup = () => {
    if (callbackIndex) {
      Pdfium.removeFunction(callbackIndex);
      callbackIndex = 0;
    }
    if (fileAccessPtr) {
      Pdfium.wasmExports.free(fileAccessPtr);
      fileAccessPtr = 0;
    }
  };

  try {
    fileAccessPtr = Pdfium.wasmExports.malloc(12);
    if (!fileAccessPtr) throw new Error('Failed to allocate PDF file access');
    callbackIndex = Pdfium.addFunction(getBlock, 'iiiii');
    const fa = new Uint32Array(Pdfium.memory.buffer, fileAccessPtr, 3);
    fa[0] = fileSize;
    fa[1] = callbackIndex;
    fa[2] = 0;

    const passwordPtr = StringUtils.allocateUTF8(password);
    const docHandle = Pdfium.wasmExports.FPDF_LoadCustomDocument(fileAccessPtr, passwordPtr);
    StringUtils.freeUTF8(passwordPtr);
    const doc = _loadDocument(docHandle, useProgressiveLoading, cleanup);
    if (!docHandle) cleanup();
    return doc;
  } catch (err) {
    cleanup();
    throw err;
  }
}

function ensurePdfBlock(url, headers, blocks, fileSize, blockId, progressCallbackId) {
  const existing = blocks.get(blockId);
  if (isCompleteBlock(existing, blockId, fileSize)) return existing;
  const start = blockId * PDF_BLOCK_BYTES;
  const end = Math.min(fileSize, start + PDF_BLOCK_BYTES) - 1;
  const fetched = syncFetchRange(url, headers, start, end);
  if (!isCompleteBlock(fetched.bytes, blockId, fileSize)) return null;
  blocks.set(blockId, fetched.bytes);
  rememberPdfBlock(url, start, end, fetched.bytes);
  reportPdfProgress(progressCallbackId, bytesHeld(blocks), fileSize);
  return fetched.bytes;
}

function isCompleteBlock(block, blockId, fileSize) {
  if (!block || !block.length) return false;
  const start = blockId * PDF_BLOCK_BYTES;
  const expected = Math.min(PDF_BLOCK_BYTES, fileSize - start);
  return block.length >= expected;
}

function bytesHeld(blocks) {
  let total = 0;
  for (const block of blocks.values()) total += block.length;
  return total;
}

function reportPdfProgress(callbackId, downloaded, total) {
  if (!callbackId) return;
  invokeCallback(callbackId, downloaded, total);
}

function syncFetchRange(url, headers, start, end) {
  const xhr = new XMLHttpRequest();
  xhr.open('GET', url, false);
  try {
    xhr.responseType = 'arraybuffer';
  } catch (_) {}
  xhr.timeout = 60000;
  xhr.setRequestHeader('Range', 'bytes=' + start + '-' + end);
  Object.keys(headers || {}).forEach((key) => {
    xhr.setRequestHeader(key, headers[key]);
  });
  xhr.send(null);
  if (xhr.status !== 200 && xhr.status !== 206) {
    throw new Error('Failed to download PDF file: ' + xhr.status + ' ' + (xhr.statusText || ''));
  }
  const bytes = toBytes(xhr.response);
  const range = xhr.getResponseHeader('content-range') || xhr.getResponseHeader('Content-Range');
  const match = range ? /bytes\s+(\d+)-(\d+)\/(\d+|\*)/i.exec(range) : null;
  const supportsRange = xhr.status === 206 && !!match && match[3] !== '*';
  return {
    supportsRange: supportsRange,
    fileSize: supportsRange ? parseInt(match[3], 10) : bytes.length,
    bytes: bytes,
  };
}

function toBytes(response) {
  if (response instanceof ArrayBuffer) return new Uint8Array(response);
  if (ArrayBuffer.isView(response)) return new Uint8Array(response.buffer, response.byteOffset, response.byteLength);
  return new Uint8Array(0);
}

function pdfCacheKey(url, start, end) {
  const path = new URL(url).pathname;
  return 'https://fm-pdf-cache.local' + path + '?b=' + start + '-' + end;
}

function rememberPdfBlock(url, start, end, bytes) {
  const key = pdfCacheKey(url, start, end);
  caches.open('fm-pdf-v1').then((cache) => {
    cache.put(key, new Response(bytes.slice().buffer)).catch(() => {});
  }).catch(() => {});
}

async function restorePdfBlocks(url, blocks) {
  try {
    const path = new URL(url).pathname;
    const prefix = 'https://fm-pdf-cache.local' + path + '?b=';
    const cache = await caches.open('fm-pdf-v1');
    const keys = await cache.keys();
    for (const req of keys) {
      if (!req.url.startsWith(prefix)) continue;
      const match = /[?&]b=(\d+)-(\d+)/.exec(req.url);
      if (!match) continue;
      const res = await cache.match(req);
      if (!res) continue;
      const start = parseInt(match[1], 10);
      const blockId = Math.floor(start / PDF_BLOCK_BYTES);
      blocks.set(blockId, new Uint8Array(await res.arrayBuffer()));
    }
  } catch (_) {}
}
