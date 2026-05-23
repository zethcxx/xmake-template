# xmake-template

A personal C++23 build template powered by **xmake**, focused on binary hardening,
strict diagnostics, and zero-bloat for **Linux** and **Windows**.

> **Scope:** Targets **GCC** and **Clang** only — no MSVC, NASM, MASM, or other toolchains.
> This is my personal configuration, but feel free to use, fork, or modify it.

## Key Features
* **Focused:** Fine-tuned for `Clang` (preferred) and `GCC`.
* **Hardening:** Stack protectors, RELRO, NX, ASLR flags.
* **Diagnostics:** Aggressive warning levels for both C and C++.
* **No-Bloat:** RTTI and Exceptions disabled by default in release builds.
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

| Key | Default | Description |
|---|---|---|
| `buildtype` | `"generic"` | `native`, `generic`, `legacy`, `modern` |
| `subsystem` | `"CONSOLE"` | `CONSOLE`, `WINDOWS`, `NATIVE`, `POSIX` (Windows) |
| `entry` | — | Custom entry point |
| `noentry` | `false` | No entry point (mutually exclusive with `entry`) |
| `payloadtype` | `false` | Enable payload mode (disables LTO, strips, nostdlib) |
| `stack_protector` | `false` | `-fstack-protector-strong` in release |
| `march` | *(from buildtype)* | Override `-march` individually |
| `mtune` | *(from buildtype)* | Override `-mtune` individually |

### Architecture Presets

```lua
target("my_app")
    set_values("buildtype", "generic")   -- march=x86-64-v2, mtune=generic (default)
    set_values("buildtype", "native")    -- march=native,    mtune=native
    set_values("buildtype", "legacy")    -- march=x86-64-v1, mtune=generic
    set_values("buildtype", "modern")    -- march=x86-64-v4, mtune=generic

    -- Individual overrides
    set_values("march", "native")
    set_values("mtune", "znver4")
```

### Custom Extras (survive flag reset)

| Method | Description |
|---|---|
| `add_cxflags(...)` | Extra C/C++ flags |
| `add_cflags(...)` | Extra C flags |
| `add_cxxflags(...)` | Extra C++ flags |
| `add_links(...)` | Extra libraries to link |
| `add_defines(...)` | Extra preprocessor defines |
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

    set_values("buildtype", "native"  )
    set_values("subsystem", "CONSOLE" )
    set        ("runargs",  {"arg1", "arg2"})

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
│   └── rules/
│       └── compile_commands.lua
├── app/
│   └── main.cpp
├── install.sh
├── install.ps1
└── README.md
```
