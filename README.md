# Joy

A framework for building full-stack web apps in Roc!

Joy is a jolt of happiness for those who want a fast, productive, fun, and statically-typed environment for full-stack development.

## Goals

Joy should provide:
* A convenient way of writing full-stack apps all in Roc (sometimes called "isomorphic" apps).
* A convenient way of communicating between the front- and back-end (think [Server Functions](https://book.leptos.dev/server/25_server_functions.html) or a protocol for message-passing over Server-Sent Events, websockets, and/or plain old requests).
* Great developer experience (feedback, iteration time, tooling, etc.)
* Great performance for the vast majority of apps, but not at any cost.

## Status

Joy is fun to play with, but it's in early development, not production-ready. Here be dragons!

You can already build single-page applications in it but the functionality is limited. Have a look at the [examples](https://github.com/niclas-ahden/joy/tree/main/examples) to get a grasp on what's currently supported. See [Joy TodoMVC](https://www.github.com/niclas-ahden/joy-todomvc) for a complete front-end example.

As an app grows, split it into pages: each page is a module with its own `Model`, `Msg`, `init`, `update` and `view`, and the app wraps them with `Html.map`, `Effect.map` and `Sub.map`. The [pages example](https://github.com/niclas-ahden/joy/tree/main/examples/pages) gives every page its own URL and holds only the page on screen, the shape of a server-rendered app, and the [spa_pages example](https://github.com/niclas-ahden/joy/tree/main/examples/spa_pages) switches pages in place and keeps every page's state.

Joy also does hydration: serve a page rendered with [`joy-html`](https://www.github.com/niclas-ahden/joy-html) and mount with `hydrate: true`, and the client's first render claims the server-rendered DOM (attaching event handlers) instead of rebuilding it. See the [TodoMVC fullstack example](https://github.com/niclas-ahden/joy/tree/main/examples/todomvc-fullstack) for the whole story: a server-rendered TodoMVC the client hydrates and persists.

Joy shares the page with whatever else is on it. Browser extensions and embedded widgets put nodes of their own among the app's (a speed control next to a video, a password manager's icon next to a field, a map drawn into an empty container), and Joy leaves them alone: it keeps track of its own nodes itself and never goes by their position in the DOM. That holds while a server-rendered page waits for its app to load, too, with one difference: nodes an extension puts in place of the page's own in that time (a translation for a text, a wrapper around a video) give way to the app's nodes when it starts, so the page never shows both.

Have fun and expect breaking changes!

### Known issues

- Known issue: on a server-rendered page, a node an extension or another script adds before Joy's script has called `mount` cannot be told apart from the server's markup. Hydration removes it when it sits in front of a node the app expects (and warns about a mismatch), or takes it for the app's own when its tag matches. Nodes added from the `mount` call on are left alone.
- Known issue: an extension that replaces the app's text with nodes of its own, the way a page translator does, leaves Joy updating the original text nodes off the page, so later changes to that text do not show. Extensions that add nodes next to the app's are fine, and so are ones that wrap them once the app is running.

## Example

A client-side counter:

```roc
app [Model, Msg, init, update, render, subscriptions] {
    pf: platform "https://github.com/niclas-ahden/joy/releases/download/0.33.0/9UWLeQeJEUkXNGmZtibc1aqpL3gm6Li65GvXxsML5vFz.tar.zst",
    html: "https://github.com/niclas-ahden/joy-html/releases/download/0.17.0/AcmwFzyfbsf5RALWNdX6cXw1cuuDXt96YfcysNqgFqoG.tar.zst",
}

import html.Html exposing [div, button, text]
import html.Attribute exposing [on_click]
import pf.Effect

Model : { count : I64 }

Msg : [Increment, Decrement]

subscriptions = |_model| []

init : Str -> (Model, List(Effect(Msg)))
init = |_| ({ count: 0 }, [])

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
    match msg {
        Increment => ({ count: model.count + 1 }, [])
        Decrement => ({ count: model.count - 1 }, [])
    }

render : Model -> Html(Msg)
render = |model|
    div(
        [],
        [
            button([on_click(Increment)], [text("+")]),
            text(model.count.to_str()),
            button([on_click(Decrement)], [text("-")]),
        ],
    )
```

[See more examples](https://github.com/niclas-ahden/joy/tree/main/examples) | [TodoMVC](https://www.github.com/niclas-ahden/joy-todomvc)

## Getting started

Start with the [Joy TodoMVC](https://www.github.com/niclas-ahden/joy-todomvc) example, and you'll have a complete front-end app setup in no time!

## Performance

Joy is tracked against the [js-framework-benchmark](https://github.com/krausest/js-framework-benchmark), with keyed and non-keyed entries. Numbers below are from a local run and give you a rough idea of our relative performance:

| | Joy (keyed) | Joy (non-keyed) | Elm (keyed) | Elm (non-keyed) | Leptos | SolidJS | React | vanilla JS |
|---|---|---|---|---|---|---|---|---|
| CPU geomean (ms) | 29.6 | 26.7 | 31.7 | 29.0 | 29.0 | 26.0 | 40.7 | 22.4 |
| Slowdown vs best | 1.42× | 1.28× | 1.52× | 1.39× | 1.39× | 1.24× | 1.95× | 1.07× |
| Memory (MB) | 3.6 | 3.6 | 1.3 | 1.3 | 3.5 | 1.0 | 2.2 | 0.8 |
| Bundle, compressed (KB) | 27.5 | 27.3 | 7.9 | 8.2 | 48.8 | 4.5 | 51.4 | 2.4 |

Bundle is the brotli-compressed transfer of everything the page loads, so for Joy that covers the WASM, the JS runtime, and the HTML. The WASM is the bulk of it at 22.1 KB, and the minified JS runtime is 5.0 KB.

Every framework in the table was measured in one session on a machine running NixOS, x86, AMD 9950X. Hopefully we can get Joy into the official benchmark soon!

## Contributing

Contributions are very welcome, including feature requests, design discussion, etc.

## Development setup

### Dependencies

Clone the repo and use the included Nix flake to set up your development environment:

```sh
$ nix develop # Oh, lord, have mercy! This is great!
```

If you don't want to use Nix then please install:

* [`roc nightly-2026-10-06-c34079d`](https://github.com/roc-lang/nightlies/releases/tag/nightly-2026-10-06-c34079d)
* `rustc` (v1.94 + `wasm32-unknown-unknown`)
* `node` (v22)
* `watchexec`
* `playwright` with its browsers, for the browser E2E suite (`npm install -g playwright && playwright install chromium firefox webkit`)

That route is also the Windows one (Nix does not run there). The scripts in the repo root are Roc programs: on Linux and macOS their shebang runs them (`./tests.roc -- --opt=speed`), on Windows hand them to roc (`roc ./tests.roc -- --opt=speed`), which works everywhere.

### Running an example

Pick an [example](https://github.com/niclas-ahden/joy/tree/main/examples) and run it like so:

```sh
$ ./watch.roc examples/hello.roc
```

The application should now be available at: [`http://localhost:8000`](http://localhost:8000)

That builds at `--opt=speed`, the default. To pick another level, pass it after the script: `./watch.roc --opt=dev examples/hello.roc`.

Start modifying the example to get a feel for it. Refresh the browser to see your changes (the app is recompiled on change but there's no browser hot-reloading yet).

### Running the tests

```sh
$ ./tests.roc --opt=speed    # Roc unit tests + the fake-DOM harnesses in tests/
$ ./e2e.roc --opt=speed      # tests/e2e/ in a real headless Chromium
$ ./e2e.roc --opt=speed --browser=all   # the same in Chromium, Firefox and WebKit
$ ./examples.roc             # each directory example's own suite (examples/*/tests.roc)
```

The harnesses in `tests/` mount the built apps on a fake DOM and cover the app and runtime logic. They find elements the way the browser suite does, by role and accessible name, label or test id (`byRole`, `byLabel`, `byTestId` in `tests/fakedom.mjs`), and they can put a work budget on a step: `meter` in `tests/harness.mjs` counts the patch ops the differ emitted and the DOM mutations made to apply them, so a harness asserts not only that the page looks right after a click but that the click cost one text write and no rebuild. The browser suite in `tests/e2e/` is built on [roc-spec](https://github.com/niclas-ahden/roc-spec) and [roc-playwright](https://github.com/niclas-ahden/roc-playwright) and covers what only a real browser can prove: real event dispatch and bubbling, `<dialog>` semantics, the History API, WebCrypto, fetch, real timers, and real keyboard and mouse input.

Both suites take the optimization level to test as their argument, and it is required here, so `./tests.roc --opt=dev` and `./e2e.roc --opt=dev` run the same suites against dev builds. Each level lands in its own `build/<opt>/` tree.

## Sponsors

Joy is sponsored by the real estate agency [BOSTHLM Fastighetsmäklare](https://www.bosthlm.se) which thrives by using technology to bolster its agents and business. Thank you!

Have a look at their search feature on [www.bosthlm.se/till-salu](https://www.bosthlm.se/till-salu) which is a front-end application written in Roc.
