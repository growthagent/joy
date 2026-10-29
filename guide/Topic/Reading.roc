import html.Html exposing [a, code, h1, h2, li, p, text, ul]
import html.Attribute exposing [class, href, rel, target]
import /Doc

## The topic "Further reading".
Reading := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Reference")]),
		h1([], [text("Further reading")]),
		h2([], [text("Joy")]),
		ul(
			[],
			[
				li(
					[],
					[
						a([href(Doc.api_docs)], [text("The API docs")]),
						text(" for every module the Joy platform exposes, and "),
						a([href("./main/")], [text("the same for the main branch")]),
						text("."),
					],
				),
				li(
					[],
					[
						a(
							[href("https://github.com/niclas-ahden/joy"), target("_blank"), rel("noopener")],
							[
								text("The Joy repository"),
							],
						),
						text(", with an "),
						code([], [text("examples")]),
						text(" folder for every feature. "),
						code([], [text("examples/fullstack")]),
						text(" is the Shelf app this guide follows, and its README explains it in more depth."),
					],
				),
				li(
					[],
					[
						a(
							[href("https://github.com/niclas-ahden/joy-html"), target("_blank"), rel("noopener")],
							[
								text("joy-html"),
							],
						),
						text(", the Html and Attribute package."),
					],
				),
				li(
					[],
					[
						a(
							[href("https://github.com/niclas-ahden/joy-todomvc"), target("_blank"), rel("noopener")],
							[
								text("Joy TodoMVC"),
							],
						),
						text(", a complete front-end app to start from."),
					],
				),
			],
		),
		h2([], [text("Roc")]),
		ul(
			[],
			[
				li(
					[],
					[
						a(
							[href("https://github.com/roc-lang/roc/blob/main/docs/mini-tutorial-new-compiler.md"), target("_blank"), rel("noopener")],
							[
								text("The Roc mini tutorial"),
							],
						),
						text(" and "),
						a(
							[href("https://github.com/roc-lang/roc/blob/main/test/echo/all_syntax_test.roc"), target("_blank"), rel("noopener")],
							[
								text("every piece of syntax in one file"),
							],
						),
						text("."),
					],
				),
			],
		),
		h2([], [text("Structuring apps in this architecture")]),
		ul(
			[],
			[
				li(
					[],
					[
						text("Richard Feldman, "),
						a(
							[href("https://www.youtube.com/watch?v=DoA4Txr4GUs"), target("_blank"), rel("noopener")],
							[
								text("Scaling Elm Apps"),
							],
						),
						text(" (Elm Europe 2017). Narrow types, the ladder of APIs, and why not to build everything as components."),
					],
				),
				li(
					[],
					[
						text("Richard Feldman, "),
						a(
							[href("https://www.youtube.com/watch?v=RN2_NchjrJQ"), target("_blank"), rel("noopener")],
							[
								text("Exploring elm-spa-example"),
							],
						),
						text(" (Oslo Elm Day 2019). Module structure, endpoints, dependencies, and the place setting."),
					],
				),
				li(
					[],
					[
						text("Richard Feldman, "),
						a(
							[href("https://www.youtube.com/watch?v=IcgmSRJHu_8"), target("_blank"), rel("noopener")],
							[
								text("Making Impossible States Impossible"),
							],
						),
						text(" (elm-conf 2016)."),
					],
				),
				li(
					[],
					[
						text("Richard Feldman, "),
						a(
							[href("https://www.youtube.com/watch?v=x1FU3e0sT1I"), target("_blank"), rel("noopener")],
							[
								text("Make Data Structures"),
							],
						),
						text(" (Elm Europe 2018). Opaque types and where state belongs."),
					],
				),
				li(
					[],
					[
						text("Evan Czaplicki, "),
						a(
							[href("https://www.youtube.com/watch?v=XpDsk374LDE"), target("_blank"), rel("noopener")],
							[
								text("The Life of a File"),
							],
						),
						text(" (Elm Europe 2017)."),
					],
				),
				li(
					[],
					[
						a(
							[href("https://guide.elm-lang.org/webapps/structure.html"), target("_blank"), rel("noopener")],
							[
								text("The Elm guide on structure"),
							],
						),
						text(", and "),
						a(
							[href("https://github.com/rtfeldman/elm-spa-example"), target("_blank"), rel("noopener")],
							[
								text("elm-spa-example"),
							],
						),
						text(" itself."),
					],
				),
			],
		),
	]
}
