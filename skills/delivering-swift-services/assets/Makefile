# The CI/CD pipeline's steps, run locally: test, build, publish the image of a main commit once as
# :<commit-sha>, deploy it to staging, then to production once staging ran it. Settings come from
# .env; GHCR credentials come from ~/.netrc (machine ghcr.io).
IMAGE_REPOSITORY := ghcr.io/<organization>/<organization>-<service>
COMMIT ?= HEAD
export IMAGE_REPOSITORY

# The tests CI runs: the committed graph and the strict flags.
test:
	swift test --disable-automatic-resolution \
		-Xswiftc -warnings-as-errors \
		--explicit-target-dependency-import-check error \
		-Xswiftc -require-explicit-sendable

# The release image, loaded locally and never pushed.
build:
	docker buildx build --platform linux/arm64 --secret id=netrc,src=$(HOME)/.netrc \
		--load --tag $(IMAGE_REPOSITORY):local .

# Pushes the image of HEAD, a clean commit on origin/main, once as :<commit-sha>.
publish:
	scripts/delivery.sh publish

# Deploys COMMIT's image to the staging applications, in order, and waits for each.
stage:
	scripts/delivery.sh stage $(COMMIT)

# Deploys COMMIT's image to production, once every staging application ran it.
deploy:
	scripts/delivery.sh deploy $(COMMIT)

.PHONY: test build publish stage deploy
