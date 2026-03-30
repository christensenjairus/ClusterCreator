# Containerd Registry Configuration

As of containerd v1.5, registry configuration is handled with `config_path`. See [documentation](https://github.com/containerd/containerd/blob/main/docs/hosts.md#registry-configuration---introduction).

For each registry, create a `<registry-name>/hosts.toml` file. For example if you have a mirror for Docker Hub, create `docker.io/hosts.toml` with:

```toml
server = "https://registry-1.docker.io"

[host."https://my-mirror.example.com"]
  capabilities = ["pull", "resolve"]
  [host."https://my-mirror.example.com".header]
    authorization = ["Basic <BASE64_ENCODED_CREDENTIALS>"]

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
```
Generate `<BASE64_ENCODED_CREDENTIALS>` with:
```sh
$ echo -n "user:password" | base64 -w 0
```
