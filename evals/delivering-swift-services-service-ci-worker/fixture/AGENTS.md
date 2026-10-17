# Example service profile

Deploy Swift 6.3 on Ubuntu Noble ARM64. `main` is the only branch: every push deploys to staging,
and production is deployed by hand.
The executable is `example-service`; its supported local SDK path is ARM64 musl.
The release image is built from the Containerfile with Docker Buildx and published to
`ghcr.io/example/example-service`. All dependencies are public.
Keep the RetryBudget behavior tests. No database or vendor fixtures are needed.
Keep the MIT license and existing owner.

The repository keeps its own formatter (four spaces, 400 columns, no other rules) and Xcode author headers.
The same executable/image supports `serve` and `worker run`. The Dokploy applications, in deploy
order, are `stg-service-41` then `stg-worker-41` for staging and `prod-service-41` then
`prod-worker-41` for production. Deploy secrets are DOKPLOY_URL and DOKPLOY_TOKEN.
