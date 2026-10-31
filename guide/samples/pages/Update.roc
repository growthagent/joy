import pf.Effect

## What a page's `update` returns, in the app's types: its model in the
## page's tag, its effects' messages in the page's message tag.
Update := [].{
	map : (page, List(Effect(page_msg))), (page -> host), (page_msg -> host_msg) -> (host, List(Effect(host_msg)))
	map = |(page, effects), to_model, to_msg| (to_model(page), effects.map(|e| e.map(to_msg)))
}
