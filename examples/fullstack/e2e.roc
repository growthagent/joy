#!/usr/bin/env roc
# Run:
#
#   ./e2e.roc
#
# To build the client and run every browser test in e2e/ (a real Chromium
# per test, via roc-playwright) in parallel. Each worker gets its own
# server on its own port against its own scratch database, wiped before
# every test, so tests cannot see each other and each starts with an empty
# todo list. Run from the example directory, inside the nix devShell (it
# provides the playwright driver and the browsers).
#
# Set `JOY_E2E_PORT` to change the first worker's port (default 8917; worker N
# listens on JOY_E2E_PORT + N).
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.27.0/HZanbveSUDoJF8LypR663eH7PpaKEKG36eErEQzmV1Qs.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.0/9ThTkhd7zrviwQpM3LvGd7pvzGhr4ZXNmWJV7pTJc9AJ.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import pf.Cmd
import pf.Env
import pf.Http
import pf.OsStr
import pf.Path
import pf.Sleep
import pf.Stdout
import pf.Utc
import spec.Spec
import spec.TestEnvironment
import Util exposing [fail!, run!]

# Each test runs its own browser; two in flight keeps memory sane.
workers = 2

main! = |_args| {
	# roc-playwright launches the browser through `playwright run-driver`,
	# so the driver must be on PATH before anything slower fails without it.
	# On Windows npm installs it as `playwright.cmd`, which a bare spawn never
	# finds, so the shim is the second try.
	if !(probe_playwright!("playwright") or probe_playwright!("playwright.cmd")) {
		fail!("playwright not found, run inside the nix devShell")?
	}

	run!("roc", ["./build.roc"])?

	base_port = U64.from_str(Env.var_str!("JOY_E2E_PORT") ?? "8917") ? |_| InvalidE2ePort

	# One server per worker, each against a scratch database recreated per
	# run so the tests start from nothing and ./todos.db never sees test
	# data. Spawned leashed, so they die with this script, pass or fail.
	#
	# A child is terminated when its last reference is released, so the
	# handles are kept until the run is over and closed below.
	servers = TestEnvironment.start!(
		{ sleep!: Sleep.millis! },
		{
			count: workers,
			spawn!: |index| spawn_server!(base_port + index.to_u64()),
			ready!: |index| answers!(base_port + index.to_u64()),
			max_attempts: 150,
			delay_ms: 100,
		},
	) ? |e| ServersNeverAnswered(Str.inspect(e))

	results = Spec.run!(
		{
			spawn_test!: |file, envs|
				Cmd.new(OsStr.utf8("roc"))
					.args_str(["--opt=speed", file])
					.envs_str(envs)
					.stdout(Capture)
					.stderr(Capture)
					.spawn_leashed!(),
			try_wait!: Cmd.Child.try_wait!,
			kill!: Cmd.Child.kill!,
			wait!: Cmd.Child.wait!,
			list_dir!: |dir| Path.utf8(dir).list!().map_ok(|entries| entries.map(Path.display)),
			print!: Stdout.line!,
			utc_now!: Utc.now!,
			sleep_millis!: Sleep.millis!,
		},
		"e2e",
		{
			max_workers: workers,
			worker_envs: |index| [("JOY_E2E_URL", url(base_port + index))],
			# A test must not see what the previous one on its worker left
			# behind, so the todos are wiped before every test.
			before_each!: |index| reset!(base_port + index),
			per_test_timeout_ms: 120_000,
			quiet: Bool.False,
			fail_fast: Bool.False,
		},
	) ? |e| CouldNotRunTheTests(Str.inspect(e))

	for server in servers {
		_ = Cmd.Child.close!(server)
	}

	passed = results.count_if(|r| r.passed)
	total = results.len()

	Stdout.line!("${passed.to_str()}/${total.to_str()} fullstack e2e tests passed")?

	if total > 0 and passed == total {
		Ok({})
	} else {
		Err(Exit(1))
	}
}

url : U64 -> Str
url = |port| "http://127.0.0.1:${port.to_str()}"

spawn_server! = |port| {
	db = "/tmp/joy-fullstack-e2e-${port.to_str()}.db"
	_ = Path.utf8(db).delete!() ?? {}
	_ = Path.utf8("${db}-wal").delete!() ?? {}
	_ = Path.utf8("${db}-shm").delete!() ?? {}

	Cmd.new_str("roc")
		.args_str(["server/main.roc"])
		.env_str("DB_PATH", db)
		.env_str("PORT", port.to_str())
		.env_str("TEST_ROUTES", "1")
		.spawn_leashed!()
		.map_err(|e| ServerSpawnFailed(e))
}

# Any response at all means the server is up.
answers! = |port|
	Http.send!(Request.from_method(GET).with_uri("${url(port)}/")).is_ok()

# A test-only route (see the test support section of server/main.roc).
reset! = |port| {
	_ = Http.send!(Request.from_method(POST).with_uri("${url(port)}/reset"))?
	Ok({})
}

probe_playwright! : Str => Bool
probe_playwright! = |program|
	Cmd.new_str(program).args_str(["--version"]).exec_output_bytes!().is_ok()
