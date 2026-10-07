# What the pages say when a request fails, in a real browser. Each failure
# that is not one of an endpoint's own errors arrives as `Server(...)`: a
# busy server, a proxy's error page, an answer the page cannot read, a
# dropped connection. The page words each one (Api.failure_text).
#
# The failures are staged in the browser: roc-playwright's `with_routes!`
# answers the client's requests before they leave the page, so the server
# needs no test hooks for them. The one real conflict, a book someone else
# borrows while the page is open, is made through the API.
#
# Run via ./tests.roc, which starts a server with the seed books and points
# E2E_URL here. The books are put back before every test.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.11.1/GJz6pEptEAmK2FqGnzJQUhF9cymdiV3vwETDdCDevAZ1.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.1/55UFmX5Ye5dNxWYzbzxQfsE54KTNwaoHNmYan163HbzB.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import http.Response
import pf.Cmd
import pf.Env
import pf.Http
import playwright.Playwright exposing [assert!]
import Browser

main! = |_args| {
	base = Env.var_str!("E2E_URL") ?? "http://127.0.0.1:8927"

	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new_str, spawn!: Cmd.spawn_leashed! },
		{ timeout: TimeoutMilliseconds(10000) },
	)?
	page.navigate!("${base}/")?
	_ = Browser.hydration!(page)?

	search = ["**/api/books/search*"]

	# A busy server (here a 503 with a body that is none of ours) says so.
	down = Fulfill({ status: 503, headers: [{ name: "content-type", value: "text/plain" }], body: Str.to_utf8("Service Unavailable") })
	page.with_routes!(rules(search, down), |routed| {
		routed.find("#search-query").fill!("moby")?
		assert!(routed.find(".catalog .status").has_text("The server is busy for a moment. Try again shortly.")) ? |e| BusyServerShouldSaySo(Str.inspect(e))
		assert!(routed.find(".catalog .status").has_class("error")) ? |e| FailureShouldLookLikeOne(Str.inspect(e))
		# The list still shows the last answer that came.
		assert!(routed.find_all(".books li").has_count(8)) ? |e| FailureShouldKeepTheList(Str.inspect(e))
		Ok({})
	})?

	# Something else answering, a proxy's error page say, is unexpected.
	proxy = Fulfill({ status: 502, headers: [{ name: "content-type", value: "text/html" }], body: Str.to_utf8("<h1>Bad gateway</h1>") })
	page.with_routes!(rules(search, proxy), |routed| {
		routed.find("#search-query").fill!("dracula")?
		assert!(routed.find(".catalog .status").has_text("Something went wrong talking to the server. Try again.")) ? |e| ProxyPageShouldBeUnexpected(Str.inspect(e))
		Ok({})
	})?

	# An answer of the wrong shape means the page is older than the server.
	outdated = Fulfill({ status: 200, headers: [{ name: "content-type", value: "application/json" }], body: Str.to_utf8("{\"books\":[]}") })
	page.with_routes!(rules(search, outdated), |routed| {
		routed.find("#search-query").fill!("eliot")?
		assert!(routed.find(".catalog .status").has_text("This page is out of date. Reload to continue.")) ? |e| IncompatibleAnswerShouldAskForAReload(Str.inspect(e))
		Ok({})
	})?

	# A dropped connection says to check it.
	page.with_routes!(rules(search, Abort(Failed)), |routed| {
		routed.find("#search-query").fill!("middlemarch")?
		assert!(routed.find(".catalog .status").has_text("Could not reach the server. Check your connection and try again.")) ? |e| DroppedConnectionShouldSaySo(Str.inspect(e))
		Ok({})
	})?

	# With the network back, the next search works and the notice goes.
	page.find("#search-query").fill!("moby")?
	assert!(page.find_all(".books li").has_count(1)) ? |e| SearchShouldRecover(Str.inspect(e))
	assert!(page.find(".catalog .status").not_has_class("error")) ? |e| NoticeShouldGo(Str.inspect(e))

	# A real conflict: someone else borrows the book while its page is open.
	page.navigate!("${base}/books/5")?
	_ = Browser.hydration!(page)?
	borrow_as!(base, "cy@example.com", 5)?
	page.find("#borrow-email").fill!("ben@example.com")?
	page.find(".borrow button").click!()?
	assert!(page.find(".book-page .error").has_text("This book is already on loan.")) ? |e| ConflictShouldSaySo(Str.inspect(e))

	browser.close!()?
	Ok({})
}

# The same action for every pattern, whatever the method.
rules = |patterns, action| patterns.map(|pattern| { pattern, method: AnyMethod, action })

# Borrow a book through the API, the way another browser would.
borrow_as! : Str, Str, I64 => Try({}, _)
borrow_as! = |base, email, book_id| {
	borrowed = Http.send!(
		Request.from_method(POST)
			.with_uri("${base}/api/books/${book_id.to_str()}/loan")
			.add_header("Content-Type", "application/json")
			.with_body(Str.to_utf8(Json.to_str({ email: email }))),
	)?
	if Response.status(borrowed) == 200 {
		Ok({})
	} else {
		Err(BorrowFailed(email, Response.status(borrowed)))
	}
}
