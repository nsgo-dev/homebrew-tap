# nsgo-dev/homebrew-tap

The Homebrew tap for [NSGo](https://nsgo.dev): it installs the prebuilt `nsgo` command from the [nsgo releases](https://github.com/nsgo-dev/nsgo/releases) on macOS and Linux, for arm64 and amd64.

```sh
brew install nsgo-dev/tap/nsgo
nsgo version
```

To upgrade to a newer release:

```sh
brew update
brew upgrade nsgo
```

The formula exists from the first nsgo release that publishes prebuilt archives, v0.3.4; until the update workflow has written it, `brew install nsgo-dev/tap/nsgo` finds no formula.

## How the formula follows releases

`Formula/nsgo.rb` is generated, never edited by hand. The [update workflow](.github/workflows/update.yml) runs every hour and on demand (Actions, update, Run workflow, with an optional release tag such as `v0.3.4`). It reads the latest nsgo release and:

- does nothing when the formula already installs that release, or when the release has no `checksums.txt` yet, as releases before v0.3.4 have none;
- refuses a release whose assets or `checksums.txt` lack any of `nsgo_<version>_darwin_arm64.tar.gz`, `nsgo_<version>_darwin_amd64.tar.gz`, `nsgo_<version>_linux_arm64.tar.gz` and `nsgo_<version>_linux_amd64.tar.gz`;
- otherwise writes the formula with `script/generate-formula.rb`, runs `brew style`, `brew audit --strict`, `brew install` and `brew test` on it, and commits it as `github-actions[bot]` with the repository's own `GITHUB_TOKEN`, only when the formula changed.

nsgo's release workflow needs no token for this repository.

## The generator

```sh
script/generate-formula.rb v0.3.4
```

It downloads `https://github.com/nsgo-dev/nsgo/releases/download/v0.3.4/checksums.txt` (sha256sum format, one `<hex>  <file>` line per archive) and writes `Formula/nsgo.rb` with one `url` and `sha256` per platform, in `on_macos` and `on_linux` blocks split into `on_arm` and `on_intel`. It refuses a tag that is not `vX.Y.Z`, a malformed `checksums.txt` and one lacking any of the four archives, and then writes nothing. Its output depends only on the tag, the base URL and the four checksums, so a second run for the same release changes nothing. It needs only Ruby's standard library, from Ruby 2.6 on.

- `--base-url URL` reads the archives and `checksums.txt` from another directory, such as a fake release on disk (`file:///...`). Homebrew scans the version from a GitHub release URL, and `brew audit --strict` refuses a version stated twice, so the formula has a `version` line only for such another base URL.
- `--checksums PATH|URL` reads `checksums.txt` from elsewhere.
- `--output FILE` writes the formula somewhere other than `Formula/nsgo.rb`.

## Testing

```sh
script/test-generator.sh /tmp/fake/nsgo.rb
```

It builds fake releases with `script/fake-release.sh`, whose archives hold an `nsgo` script printing `nsgo v<version>`, and checks that a complete release yields every archive's URL with its own checksum, that a second run changes nothing, and that a release lacking an archive, a malformed `checksums.txt`, a tag not of the form `vX.Y.Z` and a missing `checksums.txt` are refused. The [CI workflow](.github/workflows/ci.yml) runs it on macOS and Linux for every pull request, then audits, installs and tests the fake release's formula through the tap, and does the same for the committed formula once it exists.

## License

Apache-2.0, the same as NSGo. See [LICENSE](LICENSE).
