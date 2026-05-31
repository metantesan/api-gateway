# Contributing to API Gateway

Thank you for your interest in contributing! This guide covers everything you
need to get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Commit Conventions](#commit-conventions)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/metantesan/api-gateway.git
   cd api-gateway
   ```
3. Create a feature branch:
   ```bash
   git checkout -b my-feature
   ```

## Development Setup

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Running locally

1. Create a `.env` file in the project root:
   ```
   DOMAIN=localhost
   PROJECT_NAME=api-gateway
   REDIS_HOST=storage
   REDIS_PASSWORD=
   ```
2. Start the services:
   ```bash
   docker-compose up -d
   ```
3. Seed test routes in Redis:
   ```bash
   docker-compose exec storage valkey-cli SET "gateway:api:example" "http://host.docker.internal:3000"
   docker-compose exec storage valkey-cli SET "gateway:apps" '["example"]'
   ```

### Testing your changes

1. Rebuild the container:
   ```bash
   docker-compose up -d --build
   ```
2. Send test requests:
   ```bash
   curl -v http://localhost:8080/api/example/test
   curl -v http://localhost:9145/metrics
   ```

## Code Style

This project is written in **Lua** running inside **OpenResty**. Follow these
conventions:

- Use 4 spaces for indentation (no tabs)
- Use `local` variables unless a module-level export is needed
- Use `ngx.log(ngx.ERR, ...)` for error logging, not `print()`
- Keep modules in the existing directory structure:
  - `src/lua/routes/` — request routing
  - `src/lua/middleware/` — middleware (CORS, rate limiting)
  - `src/lua/metrics/` — Prometheus metrics
- Return a table from every Lua module (`_M` or local table pattern)
- Use `resty.redis` for all Redis interactions
- Use shared dicts (`ngx.shared.DICT`) for in-memory caching

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add health check endpoint
fix: correct CORS header for wildcard origins
docs: update Redis key schema documentation
refactor: extract rate limiting into reusable middleware
chore: update OpenResty base image
```

## Pull Request Process

1. **One concern per PR** — keep changes focused
2. **Update documentation** — if your change affects configuration, routing, or
   behavior, update the README or relevant docs
3. **Test manually** — ensure the gateway starts and routes correctly with your
   changes
4. **Lint your code** — run `luacheck` on any modified Lua files:
   ```bash
   luacheck src/lua/
   ```
5. **Descriptive PR title** — follow the commit convention format
6. **Link issues** — reference any related issues in the PR description

A maintainer will review your PR and may request changes before merging.

## Reporting Bugs

Open a [GitHub Issue](https://github.com/metantesan/api-gateway/issues/new)
and include:

- Steps to reproduce
- Expected vs. actual behavior
- Relevant logs (from `docker-compose logs api-gateway`)
- Your environment (OS, Docker version, OpenResty version)

## Feature Requests

Open a [GitHub Issue](https://github.com/metantesan/api-gateway/issues/new)
with the label `enhancement`. Describe:

- The problem you are trying to solve
- Your proposed solution
- Any alternative approaches you considered