# The catalog in a real browser: the server renders the books, the client
# claims that page cleanly, and searching as you type narrows the list and
# keeps the query in the URL, so a reload shows the same search. The menu
# marks where you are.
#
# Run via ./tests.roc, which starts a server with the seed books and points
# E2E_URL here. The books are put back before every test.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
	playwright: "https://github.com/niclas-ahden/roc-playwright/releases/download/0.13.1/AWahhV9oKjtqpZNTG5mUK5i86Fy1Lwssrg6yeDG52Bvy.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.7.0/BGjQKbG9U3V8cH6mRbypUAFVqFoVEu6n9bsA3QmFL1f4.tar.zst",
}

import pf.Cmd
import pf.OsStr
import pf.Duration
import pf.Env
import playwright.Playwright exposing [assert!]
import spec.Assert
import Browser

main! = |_args| {
	base = Env.var_str!("E2E_URL") ?? "http://127.0.0.1:8927"

	{ browser, page } = Playwright.launch_page_with!(
		{ new: Cmd.new, os_str: OsStr.from_str, spawn!: Cmd.Command.spawn_leashed!, millis: Duration.millis },
		{ timeout: TimeoutMilliseconds(10000) },
	)?
	page.navigate!("${base}/")?
	assert!(page.find_all(".books li").has_count(8)) ? |e| EveryBookShouldBeListed(Str.inspect(e))
	assert!(page.has_title("Catalog - Shelf")) ? |e| TitleShouldNameThePage(Str.inspect(e))
	assert!(page.find(".links a[aria-current=\"page\"]").has_text("Catalog")) ? |e| MenuShouldMarkTheCatalog(Str.inspect(e))

	# The client booted over the server's page and claimed every node.
	Assert.eq(Browser.hydration!(page)?, Browser.clean_claim) ? |e| HydrationWasNotClean(Str.inspect(e))

	# Typing searches once it pauses, and the URL follows.
	page.find("#search-query").fill!("brontë")?
	assert!(page.find_all(".books li").has_count(2)) ? |e| SearchShouldNarrowTheList(Str.inspect(e))
	assert!(page.has_url("${base}/?q=bront%C3%AB")) ? |e| UrlShouldCarryTheQuery(Str.inspect(e))

	# A reload is a server render of the same search, claimed as cleanly.
	page.navigate!("${base}/?q=bront%C3%AB")?
	assert!(page.find_all(".books li").has_count(2)) ? |e| ServerShouldRenderTheSearch(Str.inspect(e))
	assert!(page.find("#search-query").has_value("brontë")) ? |e| BoxShouldKeepTheQuery(Str.inspect(e))
	Assert.eq(Browser.hydration!(page)?, Browser.clean_claim) ? |e| SearchPageHydrationWasNotClean(Str.inspect(e))

	# Nothing found says so, an empty box lists everything again.
	page.find("#search-query").fill!("no such book")?
	assert!(page.find(".status").has_text("No books match \"no such book\".")) ? |e| EmptySearchShouldSaySo(Str.inspect(e))
	assert!(page.find_all(".books li").has_count(0)) ? |e| EmptySearchShouldListNothing(Str.inspect(e))
	page.find("#search-query").fill!("")?
	assert!(page.find_all(".books li").has_count(8)) ? |e| ClearedSearchShouldListEverything(Str.inspect(e))
	assert!(page.has_url("${base}/")) ? |e| ClearedSearchShouldClearTheUrl(Str.inspect(e))

	# A book opens its own page, which belongs to the catalog in the menu
	# and offers to lend the book.
	page.find(".books li:first-child a").click!()?
	assert!(page.has_url("${base}/books/2")) ? |e| FirstBookShouldOpen(Str.inspect(e))
	assert!(page.find("h1").has_text("Frankenstein")) ? |e| BookPageShouldShowTheTitle(Str.inspect(e))
	assert!(page.find(".links a[aria-current=\"page\"]").has_text("Catalog")) ? |e| BookPageShouldBelongToTheCatalog(Str.inspect(e))
	assert!(page.find("#borrow-email").is_visible()) ? |e| BookPageShouldOfferToLend(Str.inspect(e))

	# The menu leads to the other pages, each marked in turn.
	page.find(".links a[href=\"/books/new\"]").click!()?
	assert!(page.has_url("${base}/books/new")) ? |e| MenuShouldLeadToTheForm(Str.inspect(e))
	assert!(page.find(".links a[aria-current=\"page\"]").has_text("Add a book")) ? |e| MenuShouldMarkTheForm(Str.inspect(e))
	page.find(".links a[href=\"/loans\"]").click!()?
	assert!(page.has_url("${base}/loans")) ? |e| MenuShouldLeadToTheLoans(Str.inspect(e))
	assert!(page.find(".links a[aria-current=\"page\"]").has_text("On loan")) ? |e| MenuShouldMarkTheLoans(Str.inspect(e))
	assert!(page.find_all(".links a[aria-current]").has_count(1)) ? |e| MenuShouldMarkOneEntry(Str.inspect(e))

	browser.close!()?
	Ok({})
}
