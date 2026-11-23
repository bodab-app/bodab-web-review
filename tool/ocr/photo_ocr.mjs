import Tesseract from './tesseract.esm.min.js';

const local = name => new URL(name, import.meta.url).href;
const maxBytes = 12 * 1024 * 1024;

async function decodePhoto(bytes) {
  if (!(bytes instanceof Uint8Array) || !bytes.length || bytes.length > maxBytes) {
    throw new Error('Unsupported photo size');
  }
  const url = URL.createObjectURL(new Blob([bytes]));
  const image = new Image();
  try {
    image.src = url;
    await image.decode();
    const {naturalWidth: width, naturalHeight: height} = image;
    if (!width || !height || width * height > 65_000_000) {
      throw new Error('Unsupported photo dimensions');
    }
    const scale = Math.min(1, 3200 / Math.max(width, height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(width * scale));
    canvas.height = Math.max(1, Math.round(height * scale));
    const ctx = canvas.getContext('2d', {alpha: false});
    if (!ctx) throw new Error('Photo decoder unavailable');
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
    return canvas;
  } finally {
    URL.revokeObjectURL(url);
  }
}

// Only the engine and language models are fetched. Photo pixels go directly
// from a local canvas to a short-lived worker, never into a model cache.
export async function recognizePhoto(bytes) {
  let worker, canvas, timer;
  let finished = false;
  let rejectEngine;
  const engineError = new Promise((_, reject) => { rejectEngine = reject; });
  const run = async () => {
    canvas = await decodePhoto(bytes);
    if (finished) {
      canvas.width = canvas.height = 0;
      return '';
    }
    worker = await Tesseract.createWorker(['kor', 'eng'], Tesseract.OEM.LSTM_ONLY, {
      workerPath: local('worker.min.js'),
      workerBlobURL: false,
      corePath: local('tesseract-core-lstm.js'),
      langPath: local('.'),
      cachePath: 'bodab-static-kor-eng-bestint-v1',
      cacheMethod: 'write', // Only the public dictionaries are cached.
      errorHandler: () => rejectEngine(new Error('Photo engine unavailable')),
    });
    if (finished) {
      await worker.terminate();
      return '';
    }
    await worker.setParameters({tessedit_pageseg_mode: Tesseract.PSM.SINGLE_BLOCK});
    const result = await worker.recognize(canvas);
    return result.data.confidence >= 25 ? result.data.text.trim() : '';
  };
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error('Photo recognition timed out')), 60000);
  });
  try {
    return await Promise.race([run(), timeout, engineError]);
  } finally {
    finished = true;
    clearTimeout(timer);
    if (worker) await worker.terminate();
    if (canvas) canvas.width = canvas.height = 0;
  }
}
