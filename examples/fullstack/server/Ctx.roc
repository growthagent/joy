import pf.Server
import pf.Sqlite

## What every handler gets next to the request: the database and the
## settings the server started with. main.roc builds it once in `init!` and
## the platform hands it to every request.
Ctx := [].{
	Ctx : {
		db : Sqlite.Db,
		## Whether /test/reset exists. Only the test runner turns it on.
		test_routes : Bool,
		## What /health/ready answers. Held here because the gate closes once
		## nothing refers to it any more.
		readiness : Server.Readiness,
	}
}
