// Boot the client over the server-rendered page.
//
// The server renders the todo list into #app with the same view the client
// uses (shared/App.roc) and sends the todos as JSON in an inert
// <template id="joy-model">. Its content arrives entity-decoded, so the
// JSON reads back exactly as the server encoded it.
//
// `hydrate: true` is what makes the first paint cheap: the client's first
// render claims the server-rendered nodes and attaches its event handlers
// to them instead of clearing #app and building the tree again. If #app
// ever arrives empty (say, from a cached error page), hydration falls back
// to a plain build, so this loader serves both cases.
//
// The server serves this file, Joy's runtime.js, and the compiled app.wasm
// as siblings under /assets/, so the relative URLs below resolve.
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
