## Overview

Official community-driven vault for Vital.sandbox, serving as a curated collection and safe storage house for user-contributed resources.

Vital.vault operates as a decentralized directory using **Git Submodules**. Rather than hosting files directly, it tracks pointers to individual community-maintained repositories — keeping resources modular, ownership decentralized, and versioning cleanly decoupled.

## Getting Started

Standard cloning will produce empty directories. You must initialize submodules explicitly:

```bash
# Clone with all submodules
git clone --recurse-submodules https://github.com/ov-studio/Vital.vault

# Or, if already cloned normally:
git submodule update --init --recursive
```

## Contributing

Contributions from the community are always welcome! 🤝 

Adding a resource means registering your GitHub repository as a submodule — ensure it is clean, minimal, and fully compatible with the latest version of Vital.sandbox before following the steps below:

- **Fork** this repository to your own GitHub account.

- **Clone your fork** and navigate into it:
   ```bash
   git clone https://github.com/your-username/Vital.vault
   cd Vital.vault
   ```

- **Register your resource** by adding it as a submodule:
   ```bash
   git submodule add https://github.com/your-username/your-resource-name resources/your-resource-name
   ```

- **Commit and push** to your fork:
   ```bash
   git add .gitmodules resources/your-resource-name
   git commit -m "add: resource your-resource-name"
   git push origin main
   ```

- **Open a Pull Request** from your fork to the main repository.
