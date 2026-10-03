## Overview

Official community-driven vault for Vital.sandbox — a curated collection of user-contributed resources.

Vital.vault is a decentralized directory of **Git Submodules**. It stores pointers to community-owned repositories rather than the files themselves, so ownership stays with authors and versioning stays independent.

## Publishing a resource

Community submissions are welcome. **Publish only through the website** — do not open manual pull requests for new resources.

1. Put your resource in a **public** GitHub repository you own.
2. Add a valid [`manifest.yaml`](https://vital-sandbox.com/docs/resource/manifest) at the repository root (optional: `.vault/banner.png` for the Vault card).
3. Open [Vault](https://vital-sandbox.com/vault), sign in to workspace, choose **Publish resource**, select that repository, and open the pull request from there.

The site validates the manifest, registers the submodule, and opens a PR here for staff review. Keep the resource minimal and compatible with the latest Vital.sandbox release.

Forking this repo or running `git submodule add` yourself is **not** the supported submission path.