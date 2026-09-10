# Joy fullstack example

A small full-stack TodoMVC built on [Joy](https://github.com/niclas-ahden/joy), all in [Roc](https://www.roc-lang.org): a wasm client, a server on [basic-webserver](https://github.com/roc-lang/basic-webserver) with a SQLite database, and one shared view that the server renders to HTML and the client hydrates. It is a complete app with all of the features you'll need to get started, so clone it and start modifying it!

## Run it

You need Roc on your PATH (we recommend [`roc nightly-2026-08-26-b29bef3`](https://github.com/roc-lang/nightlies/releases/tag/nightly-2026-08-26-b29bef3)). Download the archive for your platform from that page, extract it, and put the `roc` binary on your PATH. If you use Nix, `nix develop` hands you a pinned compiler instead.

Then:

```sh
$ git clone https://github.com/niclas-ahden/joy-fullstack
$ cd joy-fullstack
$ ./dev.roc
```

Your app is now running at [`http://localhost:8000`](http://localhost:8000) (set `PORT` to change that). The client's platform (Joy) and packages arrive by URL on the first build, so there is nothing else to install or compile: no Rust, no npm, no bundler. Joy's wasm host and basic-webserver's native host both ship prebuilt inside their bundles.

`./dev.roc` is the whole dev loop: it builds the client, rebuilds it on every save, and runs the server with hot reload (edit `server/main.roc` and the new code is swapped into the running process without dropping the port). Prefer two terminals? `./watch-client.roc` and `./watch-server.roc` are the same two halves, and the one-off equivalent is:

```sh
$ ./build.roc            # build the client wasm into client/www/
$ roc server/main.roc    # then run the server
```

The database lands in `./todos.db` (set `DB_PATH` to change that) and the schema is created on first start.

Roc is a moving target, so which version you use matters. We test the latest Joy release against the newest nightly every morning and move the name above forward whenever it passes. Each [Joy release](https://github.com/niclas-ahden/joy/releases) also names the nightly it shipped against, under "Roc compiler version".

**Running from the Joy repo instead** (this directory is developed as `examples/fullstack` there): the client's header points at the checkout's platform, so build Joy's wasm host once with `./build.roc -- --opt=speed` at the repo root, and use the repo root's dev shell. Everything else is the same.

## How it works

* **One view, both sides.** `shared/` is a package both apps import: `Todo.roc` holds the todo type that crosses the wire, and `App.roc` holds the model, the messages, and the whole view. The server renders that view to HTML, the client renders it to the DOM, and hydration is the guarantee that those two agree.
* **The server owns the first paint.** On `GET /`, `server/main.roc` reads every todo from SQLite, builds the same model the client will boot with (`App.page_model`), and renders the whole HTML document with [joy-html](https://github.com/niclas-ahden/joy-html), todo list and all. The todos also ride along as JSON in an inert `<template>` element.
* **The client claims it instead of rebuilding it.** `client/www/app.js` reads that JSON out of the template and mounts the wasm app with it as flags and `hydrate: true`. The app's first render claims the server-rendered nodes and attaches its event handlers to them instead of clearing `#app` and building the tree again: the todos are on screen before the wasm even arrives, and nothing flashes when it does. How the claiming works is described in the Hydration notes in Joy's `www/runtime.js`.
* **The database is the source of truth.** `client/main.roc` is everything only the client does: booting from the flags, `update`, and the HTTP effects. Every change goes to the server first. The page shows a spinner and ignores input while the request is in flight, then the model adopts the todo list the server answered with. What you see is always what is stored, and a failure shows a notice instead of a change that never happened.
* **The filter lives in the URL.** The one piece of purely client-side state: the All/Active/Completed links push `/`, `/active`, or `/completed`, the server serves the page on all three paths, and the path rides along in the flags, so a refresh (or bookmark, or Back button) stays on that filter.

First load: SQLite to server to HTML, then the client claims that HTML and boots from the same data as flags. Every change after that: client model to HTTP request to server to SQLite. Refresh the page and the state that comes back proves the round trip worked.

## Test it

```sh
$ ./e2e.roc
```

Builds the client and runs the browser tests in `e2e/`, each a [roc-playwright](https://github.com/niclas-ahden/roc-playwright) app driving a real Chromium against its own server and scratch database, so `./todos.db` is never touched. This needs [`playwright`](https://playwright.dev) with a chromium installed (`nix develop` covers it). To add a test, drop a file ending in `_test.roc` into `e2e/`, and the existing ones show the shape: they cover hydration and editing, and then the ways things go wrong. The failure tests intercept the client's requests in the browser with roc-playwright's `with_routes!`, so a save that the server refuses, a connection that drops, a wasm that never arrives, or flags the client cannot read are all staged without any test hooks in the server.

## Where things live

* `shared/App.roc`: the application core both sides render (model, messages, views)
* `shared/Todo.roc`: the todo type both sides import
* `client/main.roc`: the client-only half (flags, update, HTTP effects)
* `client/www/app.js`: the little loader that reads the flags and hydrates the wasm app over `#app`
* `client/www/style.css`: the stylesheet. The whole directory is served under `/assets/`, so an image dropped next to it is at `/assets/its-name.png` with no server change. `build.roc` puts `app.wasm` and Joy's `runtime.js` in here too (both gitignored), so the page loads them from the same place.
* `server/main.roc`: the routes, the server-rendered page, the asset routes, and the SQLite queries
* `e2e.roc`, `e2e/*_test.roc`: the parallel test runner (roc-spec) and the browser tests (roc-playwright)
* `dev.roc`, `build.roc`, `watch-client.roc`, `watch-server.roc`: the scripts, all plain Roc

## Things to try

* Add a due date to `Todo.Todo` and let the compiler walk you through both apps.
* Drop an image into `client/www/` and use it from the view: it is already served at `/assets/<name>`.
* Break hydration on purpose: make the server render something the client's first render doesn't (say, an extra element in `page`) and watch the console warn while the page repairs itself.
* Load the page on a throttled connection: the todos are readable long before the wasm arrives, because the server rendered them.
* Swap SQLite for something else. Only `server/main.roc` knows it exists.
