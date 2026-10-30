Swagger Editor makes it easy to design, describe and document REST APIs in
OpenAPI 2.0 and 3.x. Edit the specification in YAML or JSON on one side with
live validation and inline errors, and see the rendered API documentation on
the other.

Each grain is a private editor session for one specification. The editor runs
entirely in the browser; the grain serves the upstream build over the Sandstorm
HTTP bridge, with an `api` interface at `/`.
