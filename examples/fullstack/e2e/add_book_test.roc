# Adding a book in a real browser. The form is checked in the browser with
# the same rules the server uses, so a mistake shows before anything is
# sent, and a stored book opens its own page.
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

	page.navigate!("${base}/books/new")?
	assert!(page.has_title("Add a book - Shelf")) ? |e| TitleShouldNameThePage(Str.inspect(e))
	Assert.eq(Browser.hydration!(page)?, Browser.clean_claim) ? |e| FormHydrationWasNotClean(Str.inspect(e))

	# Mistakes show at once, worded as Book.check words them.
	page.find(".new-book button").click!()?
	assert!(page.find(".new-book .error").has_text("The title is missing.")) ? |e| MissingTitleShouldSaySo(Str.inspect(e))
	page.find("#title").fill!("Emma")?
	page.find("#author").fill!("Jane Austen")?
	page.find("#year").fill!("soon")?
	page.find(".new-book button").click!()?
	assert!(page.find(".new-book .error").has_text("The year must be a number, like 1847.")) ? |e| BadYearShouldSaySo(Str.inspect(e))

	# A good book is stored and opens its own page.
	page.find("#year").fill!("1815")?
	page.find(".new-book button").click!()?
	assert!(page.has_url("${base}/books/9")) ? |e| StoredBookShouldOpen(Str.inspect(e))
	assert!(page.find("h1").has_text("Emma")) ? |e| StoredBookShouldHaveItsTitle(Str.inspect(e))
	assert!(page.find(".byline").has_text("Jane Austen, 1815")) ? |e| StoredBookShouldHaveItsByline(Str.inspect(e))
	assert!(page.find(".shelf").has_text("On the shelf.")) ? |e| StoredBookShouldBeOnTheShelf(Str.inspect(e))

	# And the catalog has it.
	page.navigate!("${base}/?q=emma")?
	assert!(page.find_all(".books li").has_count(1)) ? |e| CatalogShouldListTheNewBook(Str.inspect(e))

	browser.close!()?
	Ok({})
}
