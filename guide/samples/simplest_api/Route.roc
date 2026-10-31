Route := [].{
	Route : [Subscribe]

	to_path : Route.Route -> Str
	to_path = |Subscribe| "/subscribe"
}
