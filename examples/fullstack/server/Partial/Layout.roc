import html.Attribute exposing [attribute, class, content, href, id, lang, name, rel, src]
import html.Html exposing [a, body, div, h1, head, html, link, main, meta, p, script, section, template, text, title]
import shared.App
import shared.PartialMenu

## The HTML document around every page, so every page, a 404 included, has
## the same head, the same stylesheet and with it the same font. A message
## page shows the same menu as the app's pages (shared/Partial/Menu.roc),
## with no entry marked.
##
## An app page carries the client: the view rendered into `#app`, and the
## flags it was rendered from as JSON in an inert `<template>`, which
## client/www/app.js hands to the client so its first render claims this
## markup instead of building it again. A message page (not found, an
## error) is the server's alone and loads no client at all.
Layout := [].{
	app_page : App.Flags -> Str
	app_page = |flags| {
		model = App.init(flags)
		document(
			App.title(model),
			[
				div([id("app")], [App.view(model)]),
				# Template content is parsed but inert, and the entities the SSR
				# escaping writes decode back to the JSON as it was encoded.
				template([id("joy-model")], [text(App.encode_flags(flags))]),
			],
			WithClient,
		)
	}

	## A page with a heading and a sentence, and a way back to the catalog.
	message : Str, Str -> Str
	message = |heading, sentence|
		document(
			heading,
			[
				div(
					[class("app")],
					[
						PartialMenu.view(Nowhere),
						main(
							[class("page")],
							[
								section(
									[class("message")],
									[
										h1([], [text(heading)]),
										p([], [text(sentence)]),
										p([], [a([href("/")], [text("Back to the catalog")])]),
									],
								),
							],
						),
					],
				),
			],
			WithoutClient,
		)
}

document : Str, List(Html(msg)), [WithClient, WithoutClient] -> Str
document = |page_title, children, client| {
	client_script =
		match client {
			# Inline script text would be entity-escaped like all SSR text,
			# so the loader arrives as a module by URL instead.
			WithClient => [script([Attribute.type("module"), src("/assets/app.js")], [])]
			WithoutClient => []
		}

	Html.ssr_document(
		html(
			[lang("en")],
			[
				head(
					[],
					[
						meta([attribute("charset", "utf-8")]),
						meta([name("viewport"), content("width=device-width, initial-scale=1")]),
						title([], [text("${page_title} - Shelf")]),
						link([rel("stylesheet"), href("/assets/style.css")]),
					].concat(client_script),
				),
				body([], children),
			],
		),
	)
}
