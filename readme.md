## Overview

Official community-driven vault for Vital.sandbox — serving as a curated collection and safe storage house for user-contributed resources.

Vital.vault operates as a decentralized directory using **Git Submodules**. Rather than hosting files directly, it tracks pointers to individual community-maintained repositories — keeping resources modular, ownership decentralized, and versioning cleanly decoupled.

## Contributing

Contributions from the community are always welcome! 🤝

**Submit resources through the website — do not open manual PRs for new resources.**

1. Publish your resource in a **public** GitHub repository you own.
2. Include a valid [`manifest.yaml`](https://vital-sandbox.com/docs/resource/manifest) at the repo root (and optionally `.vault/banner.png`).
3. Open [Vault → Submit a resource](https://vital-sandbox.com/vault), sign in to workspace, pick that repository, and open the pull request from there.

The site reads your manifest, registers the submodule, and opens the PR on this repository for staff review. Keep the resource clean, minimal, and compatible with the latest Vital.sandbox release.

Manual fork / `git submodule add` workflows are **not** the supported path for community submissions.
