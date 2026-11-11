# setup-aws-emulator

A GitHub Action that installs [aws-emulator](https://github.com/aws/aws-emulator), starts it in the background, waits until it is ready, and points later steps at it. Telemetry is **off** by default.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: chadbean/setup-aws-emulator@v1
      - run: aws s3 mb s3://my-bucket   # talks to the emulator
```

## Requirements

- **Linux only** (x64 and arm64). aws-emulator runs natively only on Linux; on macOS and Windows runners the action fails with a clear error.
- `curl`, `tar`, `dpkg-deb` (or `ar` + `xz`), and `gpg` when `verify-signature` is on. GitHub-hosted Ubuntu runners have all of these. The action never installs system packages; in slim containers install them first, e.g. `apt-get install -y curl gpg ca-certificates`.

## Inputs

| Input | Default | Description |
|---|---|---|
| `version` | `latest` | Version to install, e.g. `1.0.322` (the 4-part `1.0.322.1` form is also accepted). |
| `start` | `true` | Start the emulator in the background and wait until it is ready. `false` only installs it. |
| `port` | `9297` | Port to listen on. The emulator always binds to `127.0.0.1`. The action fails if something already answers on this port. |
| `auth` | `on` | SigV4 request authentication, `on` or `off`. |
| `idle-timeout` | | Seconds of inactivity before the emulator shuts down. Empty means never. |
| `wait-timeout` | `60` | Seconds to wait for readiness before failing. |
| `telemetry` | `false` | Allow the emulator to send telemetry. See [Telemetry](#telemetry). |
| `verify-signature` | `true` | Verify the package's GPG signature against AWS's signing key (fingerprint `98BC F336 A3BE 53B7 34E9 67C5 2E5B F49B D940 F624`). |
| `export-env` | `true` | Export the client environment (below) for later steps. |

## Outputs

| Output | Description |
|---|---|
| `version` | Installed version, e.g. `1.0.322`. |
| `path` | Install directory (`bin/aws-emulator` inside it). |
| `endpoint-url` | `https://127.0.0.1:<port>` |
| `ca-file` | The emulator's CA certificate (PEM). It is regenerated on every start. |
| `credentials-file` | Shared credentials file for the emulator. |
| `config-file` | AWS config file for the emulator. |
| `pid` | Process ID of the emulator. |
| `log-file` | File the emulator's stdout and stderr go to. |

## Client environment

With `export-env: true`, later steps get:

```
AWS_ENDPOINT_URL                   https://127.0.0.1:<port>
AWS_SHARED_CREDENTIALS_FILE        ~/.aws/emulator/<port>/emulator_credentials
AWS_CONFIG_FILE                    ~/.aws/emulator/<port>/config
AWS_CA_BUNDLE                      ~/.aws/emulator/<port>/ca.pem
AWS_REGION / AWS_DEFAULT_REGION    us-east-1
AWS_EC2_METADATA_DISABLED          true
AWS_DISABLE_HOST_PREFIX_INJECTION  true
NODE_EXTRA_CA_CERTS                ~/.aws/emulator/<port>/ca.pem
```

The action does **not** set `SSL_CERT_FILE` (Rust, .NET) or `JAVA_TOOL_OPTIONS` (Java). Both replace the system trust store and would break other HTTPS calls in the job, such as `git` or `curl` to GitHub. Set them yourself in the steps that need them, using the `ca-file` output (or `truststore.p12` next to it for Java).

If `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` or `AWS_PROFILE` is already set (for example by `aws-actions/configure-aws-credentials`), it takes precedence over the emulator's credentials file. The action warns about this; unset those variables in steps that should talk to the emulator.

## Telemetry

aws-emulator collects telemetry by default. **This action turns it off unless you set `telemetry: true`.** It does this by exporting `EMULATOR_TELEMETRY=off` for the rest of the job and starting the emulator with `--telemetry off`. That covers both the emulator this action starts and any you start yourself in later steps. A later call with `telemetry: true` still starts its own emulator with telemetry on, but `EMULATOR_TELEMETRY=off` stays set for the rest of the job. See the [aws-emulator telemetry docs](https://docs.aws.amazon.com/emulator/latest/userguide/telemetry.html).

## Keeping the log

The emulator runs until the job ends. To keep its log:

```yaml
      - id: emulator
        uses: chadbean/setup-aws-emulator@v1
      # ... your tests ...
      - uses: actions/upload-artifact@v7
        if: always()
        with:
          name: aws-emulator-log
          path: ${{ steps.emulator.outputs.log-file }}
```

## Several emulators

The emulator has one region (`us-east-1`), so testing several regions means one emulator per region on different ports. Calling the action twice works, but the exported environment points at whichever emulator started **last**. Use the step outputs to wire up the others.

## Caching

The package is about 170 MB to download and about 1 GB once extracted. It is extracted into the runner tool cache (`$RUNNER_TOOL_CACHE/aws-emulator/<version>/<arch>`), so self-hosted runners reuse it across jobs. GitHub-hosted runners download it each time; the install step logs how long that took.

## License

[MIT](LICENSE). aws-emulator itself is licensed separately by AWS.
