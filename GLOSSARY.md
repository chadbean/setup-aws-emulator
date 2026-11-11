# Glossary

**Emulator**
The aws-emulator server: a local stand-in for the AWS APIs, reached through one endpoint. It accepts any Region but does not separate resources by Region, so one emulator stands for one Region and one fixed account.

**Install**
Making a specific emulator version available on the runner, so it can be run by name. Installing does not run it.

**Start**
Running an installed emulator in the background for the rest of the job.

**Ready**
A started emulator is ready once its health check answers. Before that, requests to it may fail.

**Client environment**
The settings that make AWS tools and SDKs in later steps talk to the emulator instead of real AWS: its endpoint, credentials, region and certificate.

**Region**
The AWS Region later steps send requests with. Set by the action (default `us-east-1`); the emulator itself does not choose one.

**Telemetry opt-out**
The setting that stops the emulator from sending usage data. Opted out is the default here; opting in is an explicit choice.

**Version**
A published emulator release, written in three parts (`1.0.322`). Upstream also lists a four-part form (`1.0.322.1`) that names the same release.
