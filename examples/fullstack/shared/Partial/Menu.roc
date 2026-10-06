import /Route
import html.Html exposing [a, header, nav, text]
import html.Attribute exposing [attribute, class, href]

## The header every page shares: the app's name and a menu of the main
## pages. It is a partial: a piece of view that several pages use, kept in
## Partial/ and built only from what it is given. The app's pages show it
## through App.view, and the server's own 404 and 500 pages through
## server/Partial/Layout.roc, so the whole site has one header.
##
## Each entry is a real link, so moving between pages is a navigation: the
## server renders the next page and the client claims it again. The entry
## for the section showing carries `aria-current="page"`.
Menu := [].{
	## Which entry is the current one. `Nowhere` marks none, for pages that
	## belong to no section, like a 404.
	Section : [Catalog, Loans, NewBook, Nowhere]

	view : Section -> Html(msg)
	view = |current|
		header(
			[class("top")],
			[
				a([class("brand"), href(Route.to_path(Catalog({ query: "" })))], [text("Shelf")]),
				nav(
					[class("links")],
					[
						entry("Catalog", Catalog({ query: "" }), current == Catalog),
						entry("On loan", Loans, current == Loans),
						entry("Add a book", NewBook, current == NewBook),
					],
				),
			],
		)
}

entry : Str, Route.Route, Bool -> Html(msg)
entry = |label, route, is_current| {
	marked = if is_current [attribute("aria-current", "page")] else []
	a([href(Route.to_path(route))].concat(marked), [text(label)])
}
