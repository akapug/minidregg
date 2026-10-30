# Forgejo

A self-contained Git forge for each grain. Create repositories, exchange commits over Git HTTP, and manage issues and comments through Forgejo's web interface and `/api/v1` HTTP API.

Forgejo authenticates the Sandstorm identity supplied by the HTTP bridge. SSH and external service workers are disabled; persistent repositories and the SQLite database live in the grain's own storage.
