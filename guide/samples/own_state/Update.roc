import pf.Effect

Update := [].{
	map : (page, List(Effect(page_msg))), (page -> host), (page_msg -> host_msg) -> (host, List(Effect(host_msg)))
	map = |(page, effects), to_model, to_msg| (to_model(page), effects.map(|e| e.map(to_msg)))
}
