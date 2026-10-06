import pf.Sleep

## Steps the browser tests share. Only files ending in `_test.roc` run as
## tests, so this one is just imported.
Browser := [].{
	## How the client's first render claimed the server-rendered page, once
	## the client has booted: `{"claimed":true,"mismatch":null}` is a clean
	## claim, where every node on the page is a server node.
	##
	## Polled, because the boot is the very thing awaited: no element can
	## prove it (a hydrated page looks the same before and after). Waiting
	## for it before typing also makes sure every keystroke reaches the
	## model.
	hydration! = |page| poll!(page, 100)

	clean_claim : Str
	clean_claim = "{\"claimed\":true,\"mismatch\":null}"
}

poll! = |page, attempts_left| {
	outcome = page.evaluate!(
		"window.app && window.app.hydration() ? JSON.stringify(window.app.hydration()) : 'pending'",
	) ?? "pending"
	if outcome != "pending" {
		Ok(outcome)
	} else if attempts_left == 0 {
		Err(AppNeverBooted)
	} else {
		Sleep.millis!(100)
		poll!(page, attempts_left - 1)
	}
}
