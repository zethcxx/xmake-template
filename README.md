# xmake-template

A high-performance, minimalist C++23 build template powered by **xmake**.
Designed for low-level systems programming, focusing on binary hardening,
strict diagnostics, and zero-bloat for Windows and Linux.

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
```sh
curl -sSL https://github.com/zethcxx/xmake-template/raw/main/install.sh | sh -s -- <project_name>
```

### Windows (Powershell)
```powershell
iwr -useb https://github.com/zethcxx/xmake-template/raw/main/install.ps1 | iex
```

If no project name is provided, it defaults to the current directory.

## Configuration Reference

All configuration is done via `set()` / `add()` on a `target()` in `xmake.lua`.
Flags are applied in a controlled pipeline — no magic, no surprises.

### Architecture

```lua
-- Presets (sets both march and mtune):
set("buildtype", "generic")   -- march=x86-64-v2, mtune=generic (default)
set("buildtype", "native")    -- march=native,    mtune=native
set("buildtype", "legacy")    -- march=x86-64-v1, mtune=generic
set("buildtype", "modern")    -- march=x86-64-v4, mtune=generic

-- Individual overrides (overrides buildtype for that specific flag):
set("march", "native")
set("mtune", "znver4")
```

### Linker (Windows)

| `set(...)` | Default | Description |
|---|---|---|
| `subsystem` | `"CONSOLE"` | `CONSOLE`, `WINDOWS`, `NATIVE`, `POSIX` or `EFI_APPLICATION` |
| `entry` | — | Custom entry point (`-Wl,/ENTRY:<val>`) |
| `noentry` | `false` | No entry point (`-Wl,/NOENTRY`) |

`entry` and `noentry` are mutually exclusive.

On Linux, `entry` maps to `-Wl,--entry=<val>`; `subsystem` and `noentry` are ignored.

### Custom Extras

These survive the flag pipeline (saved before reset, restored after defaults):

| `add_*()` | Description |
|---|---|
| `add_cxflags(...)` | Extra C/C++ flags |
| `add_cflags(...)` | Extra C flags |
| `add_cxxflags(...)` | Extra C++ flags |
| `add_links(...)` | Extra libraries to link |
| `add_defines(...)` | Extra preprocessor defines |

Example:
```lua
target("my_app")
    set("buildtype", "native")
    set("subsystem", "CONSOLE")

    add_cxflags ("-DSOMETHING"     )
    add_cxxflags("-DBAR=1"         )
    add_links   ("m", "pthread"    )
    add_defines ("MY_CUSTOM_DEF=1" )
```

### Full Example

```lua
set_project("MyProject")
set_version("1.0.0")
set_xmakever("2.8.0")

includes("xmake/rules/compile_commands.lua")
add_rules("vscode.compile_commands")

local act = import("xmake.actions")

target("app")
    set_default   (true         )
    set_languages ("c++23"      )
    set_kind      ("binary"     )
    set_basename  ("my_app"     )

    add_files("src/main.cpp")

    set("buildtype", "native"  )
    set("subsystem", "CONSOLE" )

    add_links("m")

    on_config ( act.configure   )
    on_prepare( act.print_info  )
    on_run    ( act.run_process )
```

## Project Structure

```
├── xmake.lua                   # Main build file
├── xmake/
│   ├── actions.lua             # Target lifecycle actions (configure, run, info)
│   ├── cfg/
│   │   ├── triple.lua          # Toolchain triple detection
│   │   └── flags.lua           # Flag pipeline (common, debug, release, linker)
│   └── rules/
│       └── compile_commands.lua# compile_commands.json generation
├── app/
│   └── main.cpp
├── install.sh                  # Quick-start script (Unix)
├── install.ps1                 # Quick-start script (Windows)
└── README.md
```
