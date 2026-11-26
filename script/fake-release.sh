#!/bin/bash
# Writes a fake nsgo release into DIR for testing the generator and the formula; see README.md.
#
#   script/fake-release.sh DIR VERSION [archive to leave out of checksums.txt...]
set -euo pipefail

if [[ "$#" -lt 2 ]]
then
  echo "usage: script/fake-release.sh DIR VERSION [archive to leave out of checksums.txt...]" >&2
  exit 2
fi
dir=$1
version=$2
shift 2

sha256() {
  if command -v sha256sum >/dev/null 2>&1
  then
    sha256sum "$@"
  else
    shasum -a 256 "$@"
  fi
}

mkdir -p "${dir}"
dir=$(cd "${dir}" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT INT TERM

printf '#!/bin/sh\necho "nsgo v%s"\n' "${version}" >"${stage}/nsgo"
chmod 755 "${stage}/nsgo"
echo "Fake license for testing the formula." >"${stage}/LICENSE"

: >"${dir}/checksums.txt"
for platform in darwin_arm64 darwin_amd64 linux_amd64 linux_arm64
do
  archive="nsgo_${version}_${platform}.tar.gz"
  # Each archive differs, so a formula that mixes up two platforms' checksums fails the tests.
  echo "Fake nsgo ${version} for ${platform}, for testing the formula." >"${stage}/README.md"
  tar -czf "${dir}/${archive}" -C "${stage}" nsgo LICENSE README.md
  omit=false
  for skipped in "$@"
  do
    if [[ "${skipped}" == "${archive}" ]]
    then
      omit=true
    fi
  done
  if [[ "${omit}" == false ]]
  then
    (cd "${dir}" && sha256 "${archive}") >>"${dir}/checksums.txt"
  fi
done
