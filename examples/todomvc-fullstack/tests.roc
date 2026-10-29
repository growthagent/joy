#!/usr/bin/env roc
# Run:
#
#   ./tests.roc
#
# To build the client and run every browser test in e2e/ (a real Chromium
# per test, via roc-playwright) in parallel. Each worker gets its own
# server on its own port against its own scratch database, wiped before
# every test, so tests cannot see each other and each starts with an empty
# todo list. Run from the example directory, inside the nix devShell (it
# provides the playwright driver and the browsers).
#
# Set `E2E_PORT` to change the first worker's port (default 8917). Worker N
# listens on E2E_PORT + N.
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.30.0/6XAUy48Jp34GANurMrMf74DtF7NdpkhnqFLHE4gHNzJy.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.7.0/BGjQKbG9U3V8cH6mRbypUAFVqFoVEu6n9bsA3QmFL1f4.tar.zst",
	http: "https://github.com/roc-lang/http/releases/download/2.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst",
}

import http.Request
import http.Response
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

# Each test runs its own browser, and two in flight keeps memory sane.
workers = 2

main! = |_args| {
	# roc-playwright launches the browser through `playwright run-driver`,
	# so the driver must be on PATH before anything slower fails without it.
	# On Windows npm installs it as `playwright.cmd`, which a bare spawn never
	# finds, so the shim is the second try.
	if !(probe_playwright!("playwright") or probe_playwright!("playwright.cmd")) {
		fail!("playwright not found, run inside the nix devShell")?
	}

	# WORKAROUND: roc-lang/roc#12693 and #12701. A shared roc cache can crash
	# this compile. Drop `--no-cache` when fixed.
	run!("roc", ["--no-cache", "./build.roc"])?

	base_port = U64.from_str(Env.var_str!("E2E_PORT") ?? "8917") ? |_| InvalidE2ePort

	# The scratch databases live in a fresh temporary directory, removed
	# again after the run, so the tests start from nothing and nothing
	# assumes a Unix /tmp.
	db_dir = Env.create_temp_dir_with_prefix!("joy-todomvc-fullstack-e2e-") ? |e| CouldNotCreateTempDir(Str.inspect(e))
	outcome = run_suite!(db_dir, base_port)
	_ = Path.delete_all!(db_dir) ?? {}
	outcome
}

# Start one server per worker, run every test against them, and report.
run_suite! = |db_dir, base_port| {
	# One server per worker, each against its own database in db_dir, so
	# ./todos.db never sees test data. Spawned leashed, so they die with
	# this script, pass or fail.
	#
	# A child is terminated when its last reference is released, so the
	# handles are kept until the run is over and closed below.
	servers = TestEnvironment.start!(
		{ sleep!: Sleep.millis! },
		{
			count: workers,
			spawn!: |index| spawn_server!(db_dir, base_port + index.to_u64()),
			ready!: |index| answers!(base_port + index.to_u64()),
			max_attempts: 150,
			delay_ms: 100,
		},
	) ? |e| ServersNeverAnswered(Str.inspect(e))

	results = Spec.run!(
		{
			new: Cmd.new,
			os_str: OsStr.from_str,
			# Leashed, so a test killed on timeout takes its browser with it.
			spawn!: Cmd.Command.spawn_leashed!,
			poll!: Cmd.Child.poll!,
			wait!: Cmd.Child.wait!,
			kill!: Cmd.Child.kill!,
			close!: Cmd.Child.close!,
			path: Path.utf8,
			list!: Path.list!,
			print!: Stdout.line!,
			now!: Utc.now!,
			sleep!: Sleep.millis!,
		},
		"e2e",
		{
			test_command: ["roc", "--opt=speed"],
			max_workers: workers,
			worker_envs: |index| [("E2E_URL", url(base_port + index))],
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

	Stdout.line!("${passed.to_str()}/${total.to_str()} todomvc-fullstack e2e tests passed")?

	if total > 0 and passed == total {
		Ok({})
	} else {
		Err(Exit(1))
	}
}

url : U64 -> Str
url = |port| "http://127.0.0.1:${port.to_str()}"

spawn_server! = |db_dir, port| {
	db = Path.display(Path.join(db_dir, "todos-${port.to_str()}.db"))
	Cmd.new(OsStr.from_str("roc"))
		.args([OsStr.from_str("server/main.roc")])
		.env(OsStr.from_str("DB_PATH"), OsStr.from_str(db))
		.env(OsStr.from_str("PORT"), OsStr.from_str(port.to_str()))
		.env(OsStr.from_str("TEST_ROUTES"), OsStr.from_str("1"))
		.spawn_leashed!()
		.map_err(|e| ServerSpawnFailed(e))
}

# The server is up once its readiness check says so, the same signal a
# container runtime or a load balancer waits for.
answers! = |port|
	match Http.send!(Request.from_method(GET).with_uri("${url(port)}/health/ready"), {}) {
		Ok(response) => Response.status(response) == 200
		Err(_) => Bool.False
	}

# A test-only route (see the test support section of server/main.roc).
reset! = |port| {
	response = Http.send!(Request.from_method(POST).with_uri("${url(port)}/reset"), {})?
	status = Response.status(response)
	if status == 200 Ok({}) else Err(ResetFailed(status))
}

probe_playwright! : Str => Bool
probe_playwright! = |program|
	match Cmd.new(OsStr.from_str(program)).args([OsStr.from_str("--version")]).run!() {
		Ok(output) => output.status == Exited(0)
		Err(_) => Bool.False
	}
