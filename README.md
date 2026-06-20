# xmake-template

A personal C++23 build template powered by **xmake**, focused on binary hardening,
strict diagnostics, zero-bloat, and **ABI-aware multi-architecture** support.

> Targets **GCC** and **Clang** across **Linux**, **Windows**, **Android**, and any
> other platform — ABI is detected automatically from the target triple.
> This is my personal configuration, but feel free to use, fork, or modify it.

## Key Features

* **Multi-ABI:** Detects `msvc`, `android`, `gnu`, `musl`, `cygnus` from the target triple.
* **Architecture presets:** Separate `buildtype` tables for `x86_64`, `arm64`, and `arm32`.
* **Hardening:** Stack protectors, RELRO, NX, ASLR, `--as-needed`, `separate-code`.
* **Diagnostics:** Aggressive warning levels for both C and C++ (Clang + GCC).
* **No-Bloat:** RTTI and Exceptions disabled by default in release (configurable).
* **LTO:** Enabled in release for Clang; linker auto-selected per ABI (`lld`, `lld-link`, or NDK default).
* **Automation:** Opt-in `compile_commands.json` via `xmake f --compile-commands=y`.

## Quick Start

### Unix (Linux/macOS)
```sh
curl -sSL https://raw.githubusercontent.com/zethcxx/xmake-template/main/install.sh | sh # -s -- <project_name>
```

### Windows (Powershell)
```sh
powershell -Command "& { $(iwr -useb https://raw.githubusercontent.com/zethcxx/xmake-template/main/install.ps1) }" # '<project_name>'"
```

## Configuration

All config is done inside a `target()` in `xmake.lua`.
Flags are applied in a controlled pipeline — no magic.

### Per-target Keys

The `get_target_value()` pipeline reads values in this priority:

1. **CLI option** — `xmake f --buildtype=native`
2. **`set_values()`** — target-level override
3. **`set()`** — target-level property (legacy)
4. **Hardcoded default** — in `flags.lua`

| Key               | Default            | Description                                           |
|-------------------|--------------------|-------------------------------------------------------|
| `buildtype`       | `"generic"`        | `native`, `generic`, `legacy`, `modern` (per arch)    |
| `subsystem`       | `"CONSOLE"`        | `CONSOLE`, `WINDOWS`, `NATIVE`, `POSIX` (Windows)     |
| `entry`           | —                  | Custom entry point                                    |
| `noentry`         | `false`            | No entry point (mutually exclusive with `entry`)      |
| `payloadtype`     | `false`            | Enable payload mode (disables LTO, strips, nostdlib)  |
| `stack_protector` | `false`            | `-fstack-protector-strong` in release                 |
| `march`           | *(from buildtype)* | Override `-march` individually                        |
| `mtune`           | *(from buildtype)* | Override `-mtune` individually                        |
| `masm`            | `"intel"`          | Assembly dialect — `"intel"` or `"att"` (x86_64 only) |
| `exceptions`      | `false`            | Enable C++ exceptions in release builds               |
| `rtti`            | `false`            | Enable RTTI in release builds                         |

### Architecture Presets

Buildtype values are architecture-dependent. Each architecture has its own table:

#### x86_64
```lua
target("my_app")
    set_values("buildtype", "generic")   -- march=x86-64-v2, mtune=generic (default)
    set_values("buildtype", "native")    -- march=native,    mtune=native
    set_values("buildtype", "legacy")    -- march=x86-64-v1, mtune=generic
    set_values("buildtype", "modern")    -- march=x86-64-v4, mtune=generic
```

#### arm64 (aarch64)
```lua
target("my_app")
    set_values("buildtype", "generic")   -- march=armv8-a,   mtune=generic (default)
    set_values("buildtype", "native")    -- march=native,    mtune=native
    set_values("buildtype", "legacy")    -- march=armv8-a,   mtune=generic
    set_values("buildtype", "modern")    -- march=armv8.5-a, mtune=generic
```

#### arm32
```lua
target("my_app")
    set_values("buildtype", "generic")   -- march=armv7-a,   mtune=generic (default)
    set_values("buildtype", "native")    -- march=native,    mtune=native
    set_values("buildtype", "legacy")    -- march=armv5te,   mtune=generic
    set_values("buildtype", "modern")    -- march=armv7ve,   mtune=generic
```

#### Individual overrides
```lua
set_values("march", "native")
set_values("mtune", "znver4")
```

### ASM dialect (x86_64 only)
```lua
set_values("masm", "intel")   -- -masm=intel (default)
set_values("masm", "att")     -- omit -masm (ATT syntax)
```

### RTTI / Exceptions in release
```lua
set_values("exceptions", true)   -- keep -fexceptions in release
set_values("rtti",       true)   -- keep -frtti in release
```

### Compilation Info

On every build the template prints detected toolchain info with ABI detection:

```
┌[ main: build/linux/x86_64/release/exec ]
│    mode     : release
│    toolchain: envs (gnu-abi)
│    compiler : gcc
│    triple   : x86_64-redhat-linux
│    march    : x86-64-v2
└─
```

The `abi` suffix (`gnu`, `msvc`, `android`, `musl`, etc.) is detected automatically from the target triple.

### Linker Flags (non-MSVC)

| Mode    | Flags                                                                                                                            |
|---------|----------------------------------------------------------------------------------------------------------------------------------|
| Release | `--gc-sections`, `--as-needed`, `--exclude-libs,ALL`, `--strip-all`, `-z relro`, `-z noexecstack`, `-z defs`, `-z separate-code` |
| Debug   | `--as-needed`, `-z relro`, `-z now`, `-z noexecstack`, `-z defs`, `-z separate-code`                                             |

### Cross-compilation

ABI detection works with any xmake toolchain. Just set the platform/arch/toolchain as usual — the template adjusts flags automatically:

```sh
xmake f -p android -a arm64-v8a -m release
xmake
```

### Local Package Repository

The template includes a local xmake package repository at `xmake/packages/` for personal libraries.
Enabled via:

```lua
add_repositories("local-repo xmake")
```

#### lbyte.stx

A header-only C++23 utility library tracked via git tags:

| Require                            | Description            |
|------------------------------------|------------------------|
| `add_requires("lbyte.stx")`        | Latest `main` branch   |
| `add_requires("lbyte.stx main")`   | Explicit `main` branch |
| `add_requires("lbyte.stx v0.2.0")` | Specific git tag       |

```lua
add_requires("lbyte.stx", {configs = {use_modules = false}})
target("app")
    add_packages("lbyte.stx")
```

The package uses GitHub archive URLs with `$(version)` substitution — no manual version entries needed
after adding a git tag.

### Custom Extras (survive flag reset)

| Method                  | Description                 |
|-------------------------|-----------------------------|
| `add_cxflags(...)`      | Extra C/C++ flags           |
| `add_cflags(...)`       | Extra C flags               |
| `add_cxxflags(...)`     | Extra C++ flags             |
| `add_links(...)`        | Extra libraries to link     |
| `add_defines(...)`      | Extra preprocessor defines  |
| `set("runargs", {...})` | Arguments passed at runtime |

### Full Example

```lua
set_project ("MyProject")
set_version ("1.0.0")
set_xmakever("2.8.0")

includes("./xmake/actions.lua")
includes("./xmake/rules/compile_commands.lua")
add_rules("vscode.compile_commands")

target("app")
    set_default   (true    )
    set_languages ("c++23" )
    set_kind      ("binary")
    set_basename  ("my_app")

    add_files("src/main.cpp")

    set_values("buildtype",   "native"  )
    set_values("subsystem",   "CONSOLE" )
    set_values("exceptions",  true      )
    set        ("runargs",    {"arg1", "arg2"})

    add_links("m")

    on_config     ( act.configure   )
    before_prepare( act.print_info  )
    on_run        ( act.run_process )
```

## Project Structure

```
├── xmake.lua
├── xmake/
│   ├── actions.lua             # Target lifecycle hooks
│   ├── cfg/
│   │   ├── triple.lua          # Toolchain detection
│   │   └── flags.lua           # Flag pipeline
│   ├── packages/
│   │   └── l/
│   │       └── lbyte.stx/
│   │           └── xmake.lua   # Local package repo
│   └── rules/
│       └── compile_commands.lua
├── app/
│   └── main.cpp
├── install.sh
├── install.ps1
└── README.md
```

