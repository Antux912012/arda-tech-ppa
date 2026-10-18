#!/usr/bin/env bash
set -euo pipefail

PPA_DIR="/home/antonio/arda-tech-ppa"
KEY_ID="4C4C7DAF16CE97060FAF10AECF9DC18F75B6C72B"

mkdir -p "$PPA_DIR/scripts"
cd "$PPA_DIR"

echo "==> 1. Cleaning and preparing APT pool & dists directories..."
rm -rf pool dists
mkdir -p \
  pool/main/m/mithrandir \
  pool/main/m/mithrandir-rs \
  pool/main/v/vingilot \
  pool/main/v/vingilot-estel \
  pool/main/i/imladris \
  pool/main/c/cachy-kernel-updater \
  pool/main/y/yt-comment-extractor \
  pool/main/y/yt-comment-extractor-service \
  pool/main/s/sulimo \
  pool/main/v/vfs5011-linux-fix \
  dists/stable/main/binary-amd64 \
  dists/stable/main/binary-all

echo "==> 2. Copying latest .deb packages into pool/main/..."
cp -v /home/antonio/Projects/mithrandir/mithrandir_0.4.0_all.deb pool/main/m/mithrandir/
cp -v /home/antonio/Projects/mithrandir-rs/mithrandir-rs_0.4.0_amd64.deb pool/main/m/mithrandir-rs/
cp -v /home/antonio/Projects/Vingilot/dist/vingilot_0.1.4-1_amd64.deb pool/main/v/vingilot/
cp -v /home/antonio/Projects/Vingilot-Estel/dist/vingilot-estel_0.1.0-alpha-1_amd64.deb pool/main/v/vingilot-estel/
cp -v /home/antonio/Projects/Imladris/imladris_0.4.0_amd64.deb pool/main/i/imladris/
cp -v /home/antonio/Projects/debian-cachy-kernel-updater/deb_dist/cachy-kernel-updater_1.1.2_all.deb pool/main/c/cachy-kernel-updater/
cp -v /home/antonio/Projects/YT-Comment-Extractor/yt-comment-extractor_0.2.0_all.deb pool/main/y/yt-comment-extractor/
cp -v /home/antonio/Projects/YT-Comment-Extractor/yt-comment-extractor-service_0.2.0_all.deb pool/main/y/yt-comment-extractor-service/
cp -v /home/antonio/Projects/Súlimo/sulimo_0.1.0_amd64.deb pool/main/s/sulimo/
cp -v /home/antonio/Projects/vfs5011-linux-fix/vfs5011-linux-fix_1.0.0_all.deb pool/main/v/vfs5011-linux-fix/

echo "==> 3. Generating Packages and Packages.gz indices..."
dpkg-scanpackages --multiversion pool/main /dev/null > dists/stable/main/binary-amd64/Packages
gzip -9c dists/stable/main/binary-amd64/Packages > dists/stable/main/binary-amd64/Packages.gz

cp -a dists/stable/main/binary-amd64/Packages dists/stable/main/binary-all/Packages
cp -a dists/stable/main/binary-amd64/Packages.gz dists/stable/main/binary-all/Packages.gz

SUITES=("stable" "bookworm" "trixie" "sid" "noble" "jammy")

for suite in "${SUITES[@]}"; do
  if [ "$suite" != "stable" ]; then
    rm -rf "dists/$suite"
    cp -a dists/stable "dists/$suite"
  fi

  echo "==> 4. Generating and signing Release / InRelease for suite: $suite..."
  pushd "dists/$suite" >/dev/null
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="Arda Tech PPA" \
    -o APT::FTPArchive::Release::Label="Arda Tech Official PPA" \
    -o APT::FTPArchive::Release::Suite="$suite" \
    -o APT::FTPArchive::Release::Codename="$suite" \
    -o APT::FTPArchive::Release::Architectures="amd64 all" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="Official Arda Tech Debian & Ubuntu APT PPA Repository by Antux912012" \
    release . > Release

  gpg --batch --yes --default-key "$KEY_ID" -abs -o Release.gpg Release
  gpg --batch --yes --default-key "$KEY_ID" --clearsign -o InRelease Release
  popd >/dev/null
done

echo "==> 5. Exporting GPG public keys..."
gpg --armor --export "$KEY_ID" > KEY.asc
gpg --export "$KEY_ID" > KEY.gpg
gpg --export "$KEY_ID" > arda-tech.gpg
gpg --export "$KEY_ID" > arda-tech-archive-keyring.gpg
touch .nojekyll

echo "==> Arda-Tech PPA built and signed successfully!"
