# Example service profile

Deploy Swift 6.3 on Ubuntu Noble ARM64. Develop is staging; main is production.
The executable is `example-service`; its supported local SDK path is ARM64 musl.
The release image is built from the Containerfile with Docker Buildx.
Keep the RetryBudget behavior tests. No database or vendor fixtures are needed.
Keep the MIT license and existing owner. Deploy secrets are DOKPLOY_URL, API_TOKEN,
APPLICATION_ID for staging and PROD_DOKPLOY_URL, PROD_API_TOKEN, PROD_APPLICATION_ID for production.

The repository keeps its own formatter (four spaces, 400 columns, no other rules) and Xcode author headers.
The same executable/image supports `serve` and `worker run`. Both process applications deploy
from that one image, with WORKER_APPLICATION_ID and PROD_WORKER_APPLICATION_ID for the worker.
