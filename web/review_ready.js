(() => {
  const loading = document.getElementById('loading');
  const actions = document.getElementById('loading-actions');
  document.getElementById('loading-retry')?.addEventListener('click', () => location.reload());

  function offerRecovery() {
    if (!actions || !loading?.isConnected) return;
    document.getElementById('loading-status').textContent = '홈을 여는 데 시간이 걸리고 있어요.';
    actions.hidden = false;
  }
  const timer = setTimeout(offerRecovery, 7000);
  function onResourceError(event) {
    if (event.target instanceof HTMLScriptElement) offerRecovery();
  }
  window.addEventListener('error', onResourceError, true);
  window.addEventListener('flutter-first-frame', () => {
    clearTimeout(timer);
    window.removeEventListener('error', onResourceError, true);
    loading?.remove();
    document.documentElement.dataset.bodabReady = 'BODAB_FLUTTER_FIRST_FRAME';
    console.info('BODAB_FLUTTER_FIRST_FRAME');
  }, { once: true });
})();
