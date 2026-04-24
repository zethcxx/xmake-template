# xmake-template

A high-performance, minimalist C++23 build template powered by **xmake**. 
Designed for low-level systems programming, focusing on binary hardening, 
strict diagnostics, and zero-bloat.

> **Note:** This is a personal configuration tailored for my workflow, 
> but feel free to use, fork, or modify it.

## Key Features
* **Toolchain Agnostic:** Fine-tuned for `Clang` (preferred) and `GCC`.
* **Hardening:** Includes stack protectors, RELRO, NX, and ASLR flags.
* **Diagnostics:** Aggressive warning levels for both C and C++.
* **No-Bloat:** RTTI and Exceptions disabled by default in release builds.
* **Automation:** Automatic `compile_commands.json` generation for LSP support.

## Quick Start

Run the following scripts from your project root to fetch the core configuration files without cloning the entire repository.

### Unix (Linux/macOS)
curl -sSL https://raw.githubusercontent.com/zethcxx/repo/main/install.sh | sh

### Windows (Powershell)
powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/zethcxx/repo/main/install.ps1 | iex"
