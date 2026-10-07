#!/usr/bin/env roc
# Run:
#
#   ./tests.roc
#
# To run every test: the expects in shared/ and server/, then the tests in
# e2e/, in parallel. Each worker gets its own server on its own port
# against its own scratch database with the seed books, and they are
# put back before every test (see `test_reset!` in server/main.roc), so a
# test never sees what another left behind. Run from this directory,
# inside the nix devShell (it provides the playwright driver and the
# browsers).
#
# Set `E2E_PORT` to change the first worker's port (default 8927,
# and worker N listens on E2E_PORT + N).
app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
	spec: "https://github.com/niclas-ahden/roc-spec/releases/download/0.6.1/55UFmX5Ye5dNxWYzbzxQfsE54KTNwaoHNmYan163HbzB.tar.zst",
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
import Script exposing [fail!, run!]

# Each browser test runs its own browser, two in flight keeps memory sane.
workers = 2

main! = |_args| {
	run!("roc", ["test", "shared/main.roc"])?
	run!("roc", ["test", "server/main.roc"])?

	# roc-playwright launches the browser through `playwright run-driver`,
	# so the driver must be on PATH before anything slower fails without it.
	# On Windows npm installs it as `playwright.cmd`, which a bare spawn never
	# finds, so the shim is the second try.
	if !(probe_playwright!("playwright") or probe_playwright!("playwright.cmd")) {
		fail!("playwright not found, run inside the nix devShell")?
	}

	run!("roc", ["./build.roc"])?

	base_port = U64.from_str(Env.var_str!("E2E_PORT") ?? "8927") ? |_| InvalidE2ePort

	# The scratch databases live in a fresh temporary directory, removed
	# again after the run, so the tests start from nothing and nothing
	# assumes a Unix /tmp.
	db_dir = Env.create_temp_dir_with_prefix!("joy-fullstack-e2e-") ? |e| CouldNotCreateTempDir(Str.inspect(e))
	outcome = run_suite!(db_dir, base_port)
	_ = Path.delete_all!(db_dir) ?? {}
	outcome
}

# Start one server per worker, run every browser test against them, and
# report.
run_suite! = |db_dir, base_port| {
	# One server per worker, each against its own database in db_dir,
	# spawned leashed so they die with this script, pass or fail. A child is terminated when its last reference is
	# released, so the handles are kept until the run is over.
	servers = TestEnvironment.start!(
		{ sleep!: Sleep.millis! },
		{
			count: workers,
			spawn!: |index| spawn_server!(db_dir, base_port + index.to_u64()),
			ready!: |index| answers!(base_port + index.to_u64()),
			# The first start compiles the server, which takes a while.
			max_attempts: 600,
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
			worker_envs: |index| [("E2E_URL", url(base_port + index))],
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

	Stdout.line!("${passed.to_str()}/${total.to_str()} e2e tests passed")?

	if total > 0 and passed == total {
		Ok({})
	} else {
		Err(Exit(1))
	}
}

url : U64 -> Str
url = |port| "http://127.0.0.1:${port.to_str()}"

spawn_server! = |db_dir, port| {
	db = Path.display(Path.join(db_dir, "library-${port.to_str()}.db"))
	Cmd.new_str("roc")
		.args_str(["server/main.roc"])
		.env_str("DB_PATH", db)
		.env_str("PORT", port.to_str())
		.env_str("TEST_ROUTES", "1")
		.spawn_leashed!()
		.map_err(|e| ServerSpawnFailed(e))
}

# The server is up once its readiness check says so, the same signal a
# container runtime or a load balancer waits for.
answers! = |port|
	match Http.send!(Request.from_method(GET).with_uri("${url(port)}/health/ready")) {
		Ok(response) => Response.status(response) == 200
		Err(_) => Bool.False
	}

reset! = |port| {
	response = Http.send!(Request.from_method(POST).with_uri("${url(port)}/test/reset"))?
	status = Response.status(response)
	if status == 200 Ok({}) else Err(ResetFailed(status))
}

probe_playwright! : Str => Bool
probe_playwright! = |program|
	Cmd.new_str(program).args_str(["--version"]).exec_output_bytes!().is_ok()
