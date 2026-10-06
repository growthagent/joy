// Boot the client over the server-rendered page.
//
// The server renders the page into #app with the same view the client uses
// (shared/App.roc) and puts the flags it rendered from, as JSON, in an
// inert <template id="joy-model">. Its content arrives entity-decoded, so
// the JSON reads back exactly as the server encoded it.
//
// `hydrate: true` makes the client's first render claim the server-rendered
// nodes and attach its event handlers to them, instead of clearing #app and
// building the tree again.
//
// The server serves this file, Joy's runtime.js and the compiled app.wasm
// side by side under /assets/, so the relative URLs below resolve. Only
// pages of the app load this file: a 404 or an error page is the server's
// alone.
import { mount } from './runtime.js';

const model = document.getElementById('joy-model');
const flags = model === null ? '' : model.content.textContent;

// Exposed globally so you can poke at the app from the devtools console.
window.app = await mount({
  wasm: new URL('./app.wasm', import.meta.url).href,
  root: document.getElementById('app'),
  flags,
  hydrate: true,
});
