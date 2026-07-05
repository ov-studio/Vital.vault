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
git clone --recurse-submodules https://github.com/ov-studio/Vital.vault
# Or if you already cloned the repository normally:
git submodule update --init --recursive
```

## Contributing

New resource additions and updates are welcome. Because this repository functions as a submodule index, adding a resource means registering your personal GitHub repository link.

### How to add your resource:

1. **Fork the repository** on GitHub to your own personal account.
2. **Clone your fork** locally and navigate into the root directory:
   ```bash
   git clone https://github.com/your-username/Vital.vault
   cd Vital.vault
   ```
3. **Run the registration command** from the repository root. Replace the placeholder URL and resource name with your actual repository details (Git handles creating the folder inside `resources/` automatically):
   ```bash
   # Add your resource repository to the vault
   git submodule add https://github.com/your-username/your-resource-name resources/your-resource-name
   ```
4. **Commit and push** the tracking changes to your fork:
   ```bash
   git add .gitmodules resources/your-resource-name
   git commit -m "add: resource your-resource-name"
   git push origin main
   ```
5. **Open a Pull Request** from your fork back to the main repository to submit your changes for review.

Ensure your target repository is clean, minimal, and fully compatible with the latest version of the core sandbox engine before submitting your registration.
