import pf.Cmd
import pf.OsStr
import pf.Stderr

## Helpers shared by the executable scripts in this directory: build.roc,
## dev.roc, watch-client.roc, watch-server.roc and tests.roc. All of them
## run from this directory.
Script :: [].{

	## Run a command with inherited stdio, exiting with the child's code when
	## it fails.
	run! : Str, List(Str) => Try({}, [Exit(I32)])
	run! = |program, args| {
		match Cmd.new(OsStr.from_str(program)).args(args.map(OsStr.from_str)).inherit_stdio().run!() {
			Ok(output) =>
				match output.status {
					Exited(0) => Ok({})
					Exited(code) => Err(Exit(code))
					Signaled(_) => Err(Exit(1))
				}

			Err(_) => Err(Exit(1))
		}
	}

	## Report a message on stderr and exit non-zero.
	fail! : Str => Try(ok, [Exit(I32)])
	fail! = |message| {
		Stderr.line!("error: ${message}") ?? {}
		Err(Exit(1))
	}
}
