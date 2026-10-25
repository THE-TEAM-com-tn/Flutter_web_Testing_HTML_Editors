// Shared bridge between the Flutter lab (the parent window) and one editor page.
//
// Every editor page loads this file first, then calls
//   LabBridge.register({ getHtml: () => '...', setHtml: (html) => {...} })
// once its editor is ready, or LabBridge.fail(error) when it could not start.
//
// Messages (all carry the `channel` given in the page URL, ?channel=...):
//   page   -> parent  { type: 'ready' }                 editor created, waiting for content
//   parent -> page    { type: 'set', html }             load this HTML
//   page   -> parent  { type: 'loaded' }                content loaded, editor usable
//   parent -> page    { type: 'get', id }               read the current HTML
//   page   -> parent  { type: 'html', id, html }
//   page   -> parent  { type: 'error', id?, message }
//
// Opened directly in a browser tab (no parent), the page loads a short demo text instead.
(function () {
  const params = new URLSearchParams(location.search);
  const channel = params.get('channel') || 'standalone';
  const standalone = window.parent === window;
  let adapter = null;

  function send(message) {
    if (standalone) return;
    window.parent.postMessage(Object.assign({ channel: channel }, message), '*');
  }

  function errorText(error) {
    return String((error && (error.message || error.reason)) || error);
  }

  window.addEventListener('message', async function (event) {
    const message = event.data;
    if (!message || message.channel !== channel || !message.type || !adapter) return;
    try {
      if (message.type === 'set') {
        await adapter.setHtml(message.html || '');
        send({ type: 'loaded' });
      } else if (message.type === 'get') {
        send({ type: 'html', id: message.id, html: String(await adapter.getHtml()) });
      }
    } catch (error) {
      send({ type: 'error', id: message.id, message: errorText(error) });
    }
  });

  window.addEventListener('error', function (event) {
    send({ type: 'error', message: event.message || 'Script error' });
  });

  window.LabBridge = {
    register: function (editorAdapter) {
      adapter = editorAdapter;
      if (standalone) {
        Promise.resolve(adapter.setHtml('<h2>Standalone preview</h2><p>This page is normally opened by the Flutter lab.</p>'));
      }
      send({ type: 'ready' });
    },
    fail: function (error) {
      console.error(error);
      send({ type: 'error', message: errorText(error) });
    },
  };
})();
