import html.Html exposing [code, div, h1, h2, p, strong, table, tbody, td, text, th, thead, tr]
import html.Attribute exposing [class]
import /Doc

## The topic "Bundles".
Bundles := [].{
	body : Doc.Body
	body = [
		p([class("eyebrow")], [text("Growing an app")]),
		h1([], [text("Bundles")]),
		p(
			[class("lead")],
			[
				text("A bundle is a Roc app on the Joy platform: one file in your project, one wasm in the browser. Which bundles a page loads decides how much code a visitor downloads, and Joy lets you choose that page by page."),
			],
		),
		h2([], [text("Three sizes, one mechanism")]),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead(
							[],
							[
								tr(
									[],
									[
										th([], [text("Shape")]),
										th([], [text("Bundles on the page")]),
										th([], [text("Root")]),
										th([], [text("Who routes")]),
									],
								),
							],
						),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [text("One bundle, every page inside")]),
										td([], [text("1")]),
										td([], [text("the whole page")]),
										td([], [text("the client, or the server with one URL per page")]),
									],
								),
								tr(
									[],
									[
										td([], [text("A bundle per page")]),
										td([], [text("1")]),
										td([], [text("the whole page")]),
										td([], [text("the server, one URL per page")]),
									],
								),
								tr(
									[],
									[
										td([], [text("Islands")]),
										td([], [text("0 to n")]),
										td([], [text("each island's element")]),
										td([], [text("the server, one URL per page")]),
									],
								),
							],
						),
					],
				),
			],
		),
		p(
			[],
			[
				text("Joy knows about none of this. "),
				code([], [text("./joy build")]),
				text(" builds every bundle it finds, and the loader mounts every bundle root it finds on a page, so a page with one root around everything and a page with four small roots are the same to it. The choice is a size question. Shelf is small, so it is one bundle with its three pages inside. A shop whose checkout is a long interactive flow would make the checkout a bundle of its own. A product page that is mostly text, with a search box, a cart button and a review form on it, is a page the server renders, with three small bundles on it, each shared with every other page that shows it and cached by the browser."),
			],
		),
		h2([], [text("A page lives where it runs")]),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead([], [tr([], [th([], [text("Kind of page")]), th([], [text("Its files")])])]),
						tbody(
							[],
							[
								tr(
									[],
									[
										td(
											[],
											[
												text("Interactive through most of its area: a search, a checkout, a dashboard"),
											],
										),
										td(
											[],
											[
												code([], [text("shared/Page/X.roc")]),
												text(" with the model, messages, view and endpoints. "),
												code([], [text("client/Page/X.roc")]),
												text(" with "),
												code([], [text("init")]),
												text(", "),
												code([], [text("update")]),
												text(" and "),
												code([], [text("subscriptions")]),
												text(". "),
												code([], [text("client/x.roc")]),
												text(", the bundle. "),
												code([], [text("server/Page/X.roc")]),
												text(", the handlers."),
											],
										),
									],
								),
								tr(
									[],
									[
										td(
											[],
											[
												text("Mostly text with a few interactive pieces on it: most pages of most sites"),
											],
										),
										td(
											[],
											[
												code([], [text("server/Page/X.roc")]),
												text(" with the handler and the view together. Nothing in "),
												code([], [text("shared/")]),
												text(" or "),
												code([], [text("client/")]),
												text(": the interactive pieces are islands, each a bundle of its own."),
											],
										),
									],
								),
								tr(
									[],
									[
										td(
											[],
											[
												text("A piece with its own state, embedded in pages or placed on them as an island"),
											],
										),
										td(
											[],
											[
												code([], [text("shared/X.roc")]),
												text(", "),
												code([], [text("client/X.roc")]),
												text(", and its handlers in "),
												code([], [text("server/X.roc")]),
												text(", named after what it is about. "),
												code([], [text("client/x.roc")]),
												text(" too when it is an island."),
											],
										),
									],
								),
							],
						),
					],
				),
			],
		),
		p(
			[],
			[
				text("Partials stay in "),
				code([], [text("shared/")]),
				text(" even when only server-rendered pages use them today, because they are the pieces a bundle page is also built from."),
			],
		),
		h2([], [text("Where bundles come from")]),
		p(
			[],
			[
				code([], [text("./joy")]),
				text(" finds bundles by their headers: every "),
				code([], [text(".roc")]),
				text(" file in "),
				code([], [text("client/")]),
				text(", at any depth, whose header is an app on the Joy platform. Modules, packages and apps on other platforms fall out on the first line. There is no manifest and nothing to register. A bundle's id is its path below "),
				code([], [text("client/")]),
				text(", without the extension. Its output directory mirrors the id, and its tag follows from it:"),
			],
		),
		Doc.code(
			Sh,
			"",
			\\./joy build
		),
		div(
			[class("table-wrap")],
			[
				table(
					[],
					[
						thead(
							[],
							[
								tr(
									[],
									[
										th([], [text("Bundle file")]),
										th([], [text("Output directory")]),
										th([], [text("Id")]),
										th([], [text("Tag")]),
									],
								),
							],
						),
						tbody(
							[],
							[
								tr(
									[],
									[
										td([], [code([], [text("client/catalog.roc")])]),
										td([], [code([], [text("dist/client/catalog/")])]),
										td([], [code([], [text("catalog")])]),
										td([], [code([], [text("Catalog")])]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("client/Checkout/cart.roc")])]),
										td([], [code([], [text("dist/client/Checkout/cart/")])]),
										td([], [code([], [text("Checkout/cart")])]),
										td([], [code([], [text("CheckoutCart")])]),
									],
								),
								tr(
									[],
									[
										td([], [code([], [text("client/app.roc")]), text(", a one-file app")]),
										td([], [code([], [text("dist/client/app/")])]),
										td([], [code([], [text("app")])]),
										td([], [code([], [text("App")])]),
									],
								),
							],
						),
					],
				),
			],
		),
		p(
			[],
			[
				text("Ids are paths below one fixed folder, so adding or removing a bundle never renames another. Naming a directory or a file, "),
				code([], [text("./joy build client/Checkout")]),
				text(", only picks what to build, and the ids stay the same. A Joy app outside "),
				code([], [text("client/")]),
				text(", a test fixture say, is not built, and "),
				code([], [text("./joy bundles")]),
				text(" lists it as found and not built. One loader, "),
				code([], [text("joy.js")]),
				text(", sits next to the bundles with the runtime built into it, holding the browser code of every feature the bundles call, so a page loads one file. "),
				code([], [text("runtime.js")]),
				text(" is written beside it for anyone who imports "),
				code([], [text("mount")]),
				text(" by hand. A bundle's directory holds only its wasm."),
			],
		),
		h2([], [text("A bundle file")]),
		p(
			[],
			[
				text("Every bundle file is the same dozen lines, and "),
				code([], [text("./joy new bundle")]),
				text(" writes them. What differs is which modules it names. A bundle for a page parses the model the server sent and hands everything to the page's two halves:"),
			],
		),
		Doc.code(
			Roc,
			"client/catalog.roc",
			\\app [Model, Msg, init, update, view, subscriptions] {
			\\    pf: platform "https://github.com/niclas-ahden/joy/releases/download/VERSION/HASH.tar.zst",
			\\    html: "https://github.com/growthagent/joy-html/releases/download/0.18.0-rc1/6eTqakHk59tsBefdx2VPuYDVZxG8SoEtzE74e7MzyoBq.tar.zst",
			\\    shared: "../shared/main.roc",
			\\}
			\\
			\\import /Page/Books/Index as Client
			\\import shared.PageBooksIndex
			\\
			\\Model : PageBooksIndex.Model
			\\Msg : PageBooksIndex.Msg
			\\
			\\init = |json|
			\\    match Json.parse(json) {
			\\        Ok(model) => Client.init(model)
			\\        Err(e) => crash "Could not read the model: \${Str.inspect(e)}"
			\\    }
			\\update = |model, msg| Client.update(model, msg)
			\\view = |model| PageBooksIndex.view(model)
			\\subscriptions = |model| Client.subscriptions(model)
		),
		p(
			[],
			[
				text("No annotations and no "),
				code([], [text("Effect")]),
				text(", "),
				code([], [text("Sub")]),
				text(" or "),
				code([], [text("Html")]),
				text(" imports: the platform's "),
				code([], [text("requires")]),
				text(" pins the six types and the rest is inferred. A bundle for an island looks the same with the island's modules in place of the page's. A bundle contains what it imports and nothing else, which is the point: the review form's bundle has the review form, and no page."),
			],
		),
		h2([], [text("On the page")]),
		p(
			[],
			[
				text("A piece that can be placed as an island offers one function, which puts its first markup inside a root that names its bundle and carries its model. The server page's view calls it where the island goes:"),
			],
		),
		Doc.sketch(
			Roc,
			"shared/ReviewForm.roc",
			\\## The form on a server-rendered page: its markup in a root with its model.
			\\island : Model -> Html(msg)
			\\island = |form| Html.bundle({ id: Bundle.path(ReviewForm), flags: Json.to_str(form), view: ReviewForm.view(form) })
		),
		Doc.sketch(
			Roc,
			"server/Page/Products/Show.roc",
			\\page! = |ctx, product_id| {
			\\    product = ProductsSql.find!(ctx.db, product_id)?
			\\    page = { product, review_form: ReviewForm.new({ product_id }) }
			\\    Layout.document(view(page))
			\\}
			\\
			\\view = |page|
			\\    Layout.page([
			\\        product_details(page.product),
			\\        ReviewForm.island(page.review_form),
			\\    ])
		),
		Doc.code(
			Html,
			"",
			\\<div data-joy-bundle="review_form" data-joy-flags='{"product_id":41,"text":"","status":"Idle"}'>
			\\  ...the form, as the server rendered it...
			\\</div>
		),
		p(
			[],
			[
				text("The loader mounts every such root, loading the wasm whose URL "),
				code([], [text("Html.document")]),
				text(" gave the root, or the one in the "),
				code([], [text("<id>/")]),
				text(" directory next to itself when it has none, and hydrating when the root has children. The same island twice on a page is two roots, two models and one cached wasm. A page that is one bundle has one root around the whole page."),
			],
		),
		p(
			[],
			[
				text("The head needs the loader's script tag and a "),
				code([], [text("preload")]),
				text(" per wasm the page uses, in the fetch mode the runtime uses, so the browser fetches the wasm while the HTML still parses. Nobody lists them. "),
				code([], [text("Layout.document")]),
				text(" renders the page with joy-html's "),
				code([], [text("Html.document")]),
				text(", which finds every root in the body, writes the hints itself and gives each root its wasm's URL, so a page that places an island gets its hint, and a page that stops placing it loses it. It takes the address your app serves "),
				code([], [text("client/")]),
				text(" at and the build's names, which is how the same layout loads Joy's files under hashed names in production and plain names while you work, from the same place. The hints are an optimisation: a page without them is one round trip slower on a first visit, and the loader mounts whatever roots it finds either way."),
			],
		),
		p(
			[],
			[
				text("Once a bundle is up, its root carries "),
				code([], [text("data-joy-mounted")]),
				text(" and "),
				code([], [text("root.joy")]),
				text(" is its handle, which is how a browser test waits for a page and how a page's own script reaches a bundle's ports."),
			],
		),
		h2([], [text("The generated list of bundles")]),
		p(
			[],
			[
				text("A page names a bundle with a tag, never a string, so a bundle that does not exist is a compile error. The tags come from "),
				code([], [text("./joy build")]),
				text(", which writes a package, "),
				code([], [text("generated/")]),
				text(", from the bundle files it found:"),
			],
		),
		Doc.sketch(
			Roc,
			"generated/Bundle.roc, generated",
			\\Bundle : [Catalog, CheckoutCart, ReviewForm, ...]
			\\
			\\path : Bundle -> Str     # CheckoutCart -> "Checkout/cart"
			\\
			\\all : List(Bundle)
		),
		p(
			[],
			[
				text("Your server and your shared package depend on it by path, like any package. It is committed, like a generated schema. "),
				code([], [text("./joy build")]),
				text(" and "),
				code([], [text("./joy dev")]),
				text(" rewrite it, only when it changes, and "),
				code([], [text("./joy doctor")]),
				text(" says when it is stale. It is written when a header in the project names it, and only then: a full-stack app's server names it from the start, and a client-only app gets it the day one of its bundles names a file in "),
				code([], [text("assets/")]),
				text(" or "),
				code([], [text("public/")]),
				text(". A one-file app whose page is HTML in "),
				code([], [text("public/")]),
				text(" never grows one. Rename a bundle file and the pages that name it stop compiling, which is what you want."),
			],
		),
		p(
			[],
			[
				text("It is made from the bundle files alone, before anything compiles, so the server and the bundles build at the same time."),
			],
		),
		h2([], [text("Islands share the document")]),
		p(
			[],
			[
				text("Two bundles on one page share no model. What they share is the DOM, and that decides where an island's edges go. The rule: "),
				strong([], [text("a region is one island when its parts need one model.")]),
				text(" A dialog and the button that opens it are one island, with the root where the button sits and the "),
				code([], [text("<dialog>")]),
				text(" rendered by the same bundle, which works because a dialog is top layer and its place in the DOM does not matter. A list of bookable showings and the booking dialog their buttons open are one island. A form whose thank-you view embeds another form is one island, with the second form embedded in the first."),
			],
		),
		p(
			[],
			[
				text("What remains between islands goes through the document, as it already does inside one app: "),
				code([], [text("DOM.show_modal(\"#id\")")]),
				text(" opens a dialog whoever owns it, and a keyboard subscription hears a key whichever island asked. Two islands listening for Escape are fine as long as each checks its own state first. If two islands ever had to share a value, the mechanism would be a document event, and the better answer is nearly always to make them one island."),
			],
		),
		p(
			[],
			[
				text("One bundle per island type, not one for all of them. A page then downloads the islands it places and nothing else, each cached across the whole site, and every bundle runs one piece with no wiring inside. Memory is the same either way, one instance per root, which is also why a page should have a few islands and not twenty."),
			],
		),
	]
}
