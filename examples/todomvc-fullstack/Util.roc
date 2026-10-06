import pf.Cmd
import pf.Stderr

## Helpers shared by the executable scripts in the repo root: build.roc,
## serve.roc, dev.roc and tests.roc. All of them are run from the repo root.
Util :: [].{

	## Run a command with inherited stdio, exiting with the child's code when it
	## fails.
	run! : Str, List(Str) => Try({}, [Exit(I32)])
	run! = |program, args| {
		match Cmd.new_str(program).args_str(args).exec_exit_code!() {
			Ok(0) => Ok({})
			Ok(code) => Err(Exit(code))
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
