Route := [].{
	Route : [Contact]

	to_path : Route.Route -> Str
	to_path = |Contact| "/contact"
}
