## Overview

Official community-driven vault for Vital.sandbox that serves as a curated collection and safe storage house for user-contributed resources.

Vital.vault acts as a decentralized directory utilizing **Git Submodules**. Rather than hosting raw source files directly, this repository tracks pointers to individual, community-maintained repositories. This keeps resources modular, allows contributors to maintain sole ownership over their files, and enables clean, decoupled project versioning.

## Structure

| Path | Description |
|---|---|
| `resources/` | Git submodules linking to standalone, community-maintained resources |

## Getting Started

Because this vault relies on submodules, standard cloning will download empty directories. You must initialize and pull the submodule links explicitly:

```bash
# Clone the vault alongside all tracking submodules
git clone --recurse-submodules https://github.com

# Or if you already cloned the repository normally:
git submodule update --init --recursive
```

## Contributing

New resource additions and updates are welcome. Because this repository functions as a submodule index, adding a resource means registering your personal GitHub repository link. 

To add a resource, open a pull request that runs the following registration command inside the correct directory layer:

```bash
# Example: Adding your resource repository to the vault
git submodule add https://github.com resources/your-resource-name
```

Ensure your target repository is clean, minimal, and fully compatible with the latest version of the core sandbox engine before submitting your registration.
