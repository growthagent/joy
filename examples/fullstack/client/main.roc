# The client: boots from the flags the server put in the page, hydrates the
# server-rendered #app, and owns everything only the client does: reacting
# to messages and talking to the API.
#
# The model, the messages and the views live in shared/ (App.roc and the
# modules under shared/Page/), because the server renders the same view for
# the first paint. Each page's messages arrive wrapped in that page's tag of
# App.Msg, and the page's module under client/Page/ handles them.
app [Model, Msg, init, update, view, subscriptions] {
	pf: platform "../../../platform/main.roc",
	html: "https://github.com/niclas-ahden/joy-html/releases/download/0.17.1/AcmwFzyfbsf5RALWNdX6cXw1cuuDXt96YfcysNqgFqoG.tar.zst",
	shared: "../shared/main.roc",
}

import /Page/Books/Index as ClientBooksIndex
import /Page/Books/New as ClientBooksNew
import /Page/Books/Show as ClientBooksShow
import /Page/Loans/Index as ClientLoansIndex
import html.Html
import pf.Console
import pf.Effect
import shared.App

Model : App.Model

Msg : App.Msg

view : Model -> Html(Msg)
view = |model| App.view(model)

subscriptions = |_model| []

# The flags are the JSON the server rendered the page from (see App.Flags).
# Flags the client cannot read leave it with no page to show, which it says
# instead of guessing. The console gets the details.
init : Str -> (Model, List(Effect(Msg)))
init = |flags|
	match App.decode_flags(flags) {
		Ok(decoded) => (App.init(decoded), [])
		Err(BadFlags(problem)) => (
			{ page: Broken },
			[Console.log("[ERROR] Could not read the flags: ${problem}\nFlags: ${flags}")],
		)
	}

update : Model, Msg -> (Model, List(Effect(Msg)))
update = |model, msg|
	match (model.page, msg) {
		(Catalog(page), CatalogMsg(page_msg)) => on_page(model, ClientBooksIndex.update(page, page_msg), |p| Catalog(p), |m| CatalogMsg(m))
		(Book(page), BookMsg(page_msg)) => on_page(model, ClientBooksShow.update(page, page_msg), |p| Book(p), |m| BookMsg(m))
		(Loans(page), LoansMsg(page_msg)) => on_page(model, ClientLoansIndex.update(page, page_msg), |p| Loans(p), |m| LoansMsg(m))
		(NewBook(page), NewBookMsg(page_msg)) => on_page(model, ClientBooksNew.update(page, page_msg), |p| NewBook(p), |m| NewBookMsg(m))
		# A message for another page than the one showing has nowhere to go.
		_ => (model, [])
	}

## A page's update, put back into the app's model and messages.
on_page : Model, (page, List(Effect(page_msg))), (page -> App.Page), (page_msg -> Msg) -> (Model, List(Effect(Msg)))
on_page = |model, (page, effects), to_page, to_msg|
	({ ..model, page: to_page(page) }, effects.map(|effect| effect.map(to_msg)))
