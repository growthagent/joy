# Joy Field Guide

A guide to building and structuring web apps with Joy, kept here so it is
not lost. It is a starting point, not a finished text.

`index.html` is the guide as one page. Open it in a browser. The index on
the left lists the topics, the search box filters them, and the page
needs nothing but the file itself (the fonts come from Google Fonts and
fall back to system fonts offline).

It is also the landing page of Joy's GitHub Pages site. The Deploy docs
workflow publishes it at the root and replaces `LATESTVERSION` with the
newest release that has docs, so the API docs links in the index point at
that release and at the main branch. Opened from a checkout, those links
lead nowhere.

## What it covers

Four parts, 24 topics:

- **Start here**: what Joy is, a first app, the update loop, views,
  effects, subscriptions and flags.
- **Growing an app**: pages, the three folders (shared, client, server),
  server rendering and hydration, bundles, one type for every URL, the
  routing table and typed endpoints.
- **Structuring for scale**: picking the simplest API, partials,
  components, state as types, narrow types, messages as facts and
  organizing modules.
- **Reference**: adding a page, the `./joy` command and further reading.

The examples assume the `examples/fullstack` app (Shelf, a small lending
library) and the bundle loader described in the Bundles topic. Where the
guide and the code in this repository disagree, the code is right and the
guide needs updating.

One exception: what the guide says about `./joy`, in The ./joy command and
wherever else it comes up, follows a design that is only partly built.
There the guide is ahead of the code.
