#!/bin/bash
# Tests script/generate-formula.rb against fake releases; see README.md.
#
#   script/test-generator.sh [OUT]
#
# OUT keeps the formula generated for the complete fake release, whose files go to release/ next to OUT.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT INT TERM
out=${1:-${work}/nsgo.rb}
release="$(dirname "${out}")/release"
version=0.0.1

fail() {
  echo "test-generator: $*" >&2
  exit 1
}

generate() {
  ruby "${root}/script/generate-formula.rb" "$@"
}

"${root}/script/fake-release.sh" "${release}" "${version}"
generate --base-url "file://${release}" --output "${out}" "v${version}"
for platform in darwin_arm64 darwin_amd64 linux_amd64 linux_arm64
do
  archive="nsgo_${version}_${platform}.tar.gz"
  sum=$(awk -v a="${archive}" '$2 == a { print $1 }' "${release}/checksums.txt")
  url_line="url \"file://${release}/${archive}\""
  # The sha256 line must follow the archive's own url line.
  grep -A1 -F "${url_line}" "${out}" | grep -q -F "sha256 \"${sum}\"" ||
    fail "the formula lacks ${archive} with its checksum"
done
grep -q -F "version \"${version}\"" "${out}" || fail "the formula of a release outside GitHub lacks version ${version}"

cp "${out}" "${work}/first.rb"
generate --base-url "file://${release}" --output "${out}" "v${version}"
cmp -s "${work}/first.rb" "${out}" || fail "a second run for the same release changed the formula"

# For a GitHub release Homebrew scans the version from the URL, so the formula must not state it.
generate --checksums "${release}/checksums.txt" --output "${work}/github.rb" "v${version}"
grep -q -F "url \"https://github.com/nsgo-dev/nsgo/releases/download/v${version}/nsgo_${version}_linux_arm64.tar.gz\"" \
  "${work}/github.rb" || fail "the formula of a GitHub release lacks its URL"
if grep -q "^  version " "${work}/github.rb"
then
  fail "the formula of a GitHub release states its version"
fi

refused() {
  local name=$1
  shift
  local status=0
  ruby "${root}/script/generate-formula.rb" --output "${work}/refused.rb" "$@" 2>"${work}/stderr" || status=$?
  [[ "${status}" -ne 0 ]] || fail "${name}: the generator accepted it"
  [[ ! -e "${work}/refused.rb" ]] || fail "${name}: the generator wrote a formula"
  local message
  message=$(<"${work}/stderr")
  echo "refused ${name}: ${message}"
}

"${root}/script/fake-release.sh" "${work}/partial" "${version}" "nsgo_${version}_linux_arm64.tar.gz"
refused "a release lacking an archive" --base-url "file://${work}/partial" "v${version}"

printf 'not a checksum line\n' >"${work}/malformed.txt"
refused "a malformed checksums.txt" --base-url "file://${release}" --checksums "${work}/malformed.txt" "v${version}"

refused "a tag that is not vX.Y.Z" --base-url "file://${release}" "${version}"
refused "a missing checksums.txt" --base-url "file://${work}/nowhere" "v${version}"

echo "test-generator: ok"
