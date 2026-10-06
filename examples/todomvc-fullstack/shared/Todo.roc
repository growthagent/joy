## The todo item as both sides of the app know it. The server reads and
## writes these against SQLite and the client renders and edits them, so the
## one definition lives here and JSON keeps them in sync over the wire.
##
## The nominal `Todo` wrapper is just the module: a file named Todo.roc must
## define a nominal `Todo`, and the record alias lives inside it, so both
## apps write `Todo.Todo` in their annotations.
Todo := [].{
	Todo : { id : I64, title : Str, done : Bool }
}
