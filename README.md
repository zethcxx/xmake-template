# cpp-xmake

A personal **C++23** build template powered by [xmake](https://xmake.io).
It focuses on strict diagnostics, binary hardening, multi-ABI cross-compilation,
C++20/23 modules and a small set of reusable project rules.

> Targets **GCC** and **Clang** on Linux, Windows, Android and other platforms.
> The ABI is detected automatically from the target triple.
> This is my personal setup; feel free to use, fork or modify it.

Tested with xmake `3.1.x`, GCC `16.x` and Clang `22.x` on Linux.

## Highlights

- **C++23 modules + header units** — each target keeps its own header-unit BMI,
  so targets with different flags (`-fexceptions`, `-fno-rtti`, ...) can coexist.
- **Fallback scanner normalization** — aligned imports such as `import std   ;`
  or `import <cstdio> ;` are normalized before dependency resolution.
- **Multi-ABI** — detects `msvc`, `android`, `gnu`, `musl` and `cygnus` from the
  target triple.
- **Architecture presets** — separate `buildtype` tables for `x86_64`, `arm64`
  and `arm32`.
- **Hardening** — stack protector, RELRO, NX, ASLR, `--as-needed`,
  `--gc-sections` and `separate-code`.
- **Strict diagnostics** — aggressive warning sets for GCC and Clang.
- **No bloat by default** — exceptions and RTTI are disabled in release.
- **LTO** — enabled for Clang release builds, with the linker selected per ABI.
- **Extras** — `compile_commands.json`, static-file embedding, payload
  extraction, release-bundle fetching and a `pinfo` task.

## Requirements

- xmake `>= 3.0`
- A compiler with C++23 modules support (GCC 16+ or Clang 22+ recommended)
- Optional: `llvm-objcopy` or `objcopy` for `payload_extract`
- Optional: network access (or a local path) for `bundle.fetch`

## Installation

### Unix (Linux/macOS)

```sh
curl -sSL https://raw.githubusercontent.com/zethcxx/xmake-template/main/install.sh | bash -s -- my-project
```

### Windows (PowerShell)

```powershell
powershell -Command "& { $(iwr -useb https://raw.githubusercontent.com/zethcxx/xmake-template/main/install.ps1) 'my-project' }"
```

The scripts download `xmake.lua`, the complete `xmake/` tree and `src/main.cpp`.

## Project layout

```text
.
├── xmake.lua
├── xmake/
│   ├── modules/
│   │   ├── actions.lua          # configure / after_build / run hooks
│   │   ├── embed_gen.lua        # byte-array and embed file generator
│   │   ├── embed_hex.lua        # hex formatting helper
│   │   └── cfg/
│   │       ├── flags.lua        # compiler/linker flag pipeline
│   │       ├── infobox.lua      # pinfo renderer
│   │       └── triple.lua       # toolchain/triple/ABI detection
│   ├── packages/
│   │   └── l/lbyte.stx/xmake.lua
│   └── rules/
│       ├── bundle.lua            # bundle.fetch
│       ├── compile_commands.lua  # vscode.compile_commands
│       ├── embed_cxx.lua         # embed_cxx
│       ├── headerunit_dirs.lua   # cxx.headerunit_dirs
│       ├── payload_extract.lua   # payload_extract
│       ├── scanner_norm.lua      # cxx.scanner_norm
│       └── tasks.lua             # pinfo / setup-perl tasks
├── src/main.cpp
├── install.sh
├── install.ps1
└── README.md
```

Generated files live under `build/`; `.xmake/` stores xmake's local state.
Both are ignored by git.

## Configuration

### Target skeleton

```lua
target("app")
    set_default  (true    )
    set_languages("c++23" )
    set_kind     ("binary")
    set_basename ("app"   )

    add_rules("cxx.headerunit_dirs")
    add_rules("cxx.scanner_norm"   )

    add_files("src/main.cpp")
    add_packages("lbyte.stx")

    set_values("buildtype" , "generic")
    set_values("exceptions", true     )
    set_values("rtti"      , true     )

    on_config  ("actions.configure"  )
    after_build("actions.after_build")
    on_run     ("actions.run_process")
```

The three `actions.*` hooks are required if you want the flag pipeline, shared
library copying, payload dependency handling, `.lldbinit` generation and the
`xmake run` wrapper.

### Value resolution

Per-target values are resolved in this order:

1. CLI configuration — `xmake f --buildtype=native`
2. `set_values("key", value)` on the target
3. `set("key", value)` (legacy target property)
4. Hardcoded default in `xmake/modules/cfg/flags.lua`

| Key                | Default              | Accepted / effect                                                                                                         |
| ------------------ | -------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `buildtype`        | `"generic"`          | `native`, `generic`, `legacy`, `modern` (per architecture)                                                                |
| `subsystem`        | `"CONSOLE"`          | `CONSOLE`, `WINDOWS`, `NATIVE`, `POSIX`; `EFI_APPLICATION` on Windows hosts                                               |
| `entry`            | —                    | Custom entry-point symbol                                                                                                 |
| `noentry`          | `false`              | Omit the entry point; mutually exclusive with `entry`                                                                     |
| `freestanding`     | `false`              | `-nostdlib`, no stack protector, default `-O2`                                                                            |
| `stack_protector`  | `true`               | `-fstack-protector-strong` in release; `false` disables it                                                                |
| `optimize`         | auto                 | `size` (`-Oz`/`-Os`), `fast` (`-O2`), `faster` (`-O3`) or a raw flag; auto means `-O2` when freestanding, otherwise `-O3` |
| `march`            | from `buildtype`     | Override `-march`                                                                                                         |
| `mtune`            | from `buildtype`     | Override `-mtune`                                                                                                         |
| `masm`             | `"intel"`            | `intel` adds `-masm=intel`; any other value omits it (ATT)                                                                |
| `exceptions`       | `false`              | Release only: `-fexceptions` / `-fno-exceptions`                                                                          |
| `rtti`             | `false`              | Release only: `-frtti` / `-fno-rtti`                                                                                      |
| `run.detach`       | `false`              | Run the target detached from `xmake run`                                                                                  |

`buildtype` presets:

| Architecture   | `native`                      | `generic`             | `legacy`              | `modern`              |
| -------------- | ----------------------------- | --------------------- | --------------------- | --------------------- |
| `x86_64`       | `-march=native -mtune=native` | `x86-64-v2 / generic` | `x86-64-v1 / generic` | `x86-64-v4 / generic` |
| `arm64`        | `-march=native -mtune=native` | `armv8-a / generic`   | `armv8-a / generic`   | `armv8.5-a / generic` |
| `arm32`        | `-march=native -mtune=native` | `armv7-a / generic`   | `armv5te / generic`   | `armv7ve / generic`   |

`march` and `mtune` can be overridden individually:

```lua
set_values("buildtype", "native")
set_values("march"    , "znver4")
set_values("mtune"    , "znver4")
```

### Release behaviour

```lua
set_values("exceptions"    , true )  -- keep -fexceptions
set_values("rtti"          , true )  -- keep -frtti
set_values("stack_protector", false) -- disable -fstack-protector-strong
set_values("optimize"      , "size") -- -Oz (Clang) or -Os (GCC)
```

### Linker flags

| Mode    | Non-MSVC flags                                                                                                                   |
| ------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Release | `--gc-sections`, `--as-needed`, `--exclude-libs,ALL`, `--strip-all`, `-z relro`, `-z noexecstack`, `-z defs`, `-z separate-code` |
| Debug   | `--as-needed`, `-z relro`, `-z now`, `-z noexecstack`, `-z defs`, `-z separate-code`                                             |

`freestanding` adds `-nostdlib`. `entry` adds `-Wl,--entry=<symbol>` (or
`/ENTRY:<symbol>` for MSVC).

### Info box

`xmake pinfo [target]` prints the cached configuration without reconfiguring.
With no target name it prints every target.

```text
┌[ app: build/linux/x86_64/release/app ]
│    toolchain    : gcc - gcc (gnu-abi)
│    triple       : x86_64-redhat-linux
│    march        : x86_64
│    mode         : release
│    payload.code : build/linux/x86_64/release/code.bin (.text)
└─
```

The `payload.*` lines come from `payload_extract` targets (one line per
configured payload).

### Cross-compilation

ABI detection works with any xmake toolchain:

```sh
xmake f -p android -a arm64-v8a -m release
xmake
```

For MSVC-compatible debug builds, `actions.configure` writes
`build/lldb/<target>.lldbinit` with a `target.source-map` directive:

```powershell
lldb -s build/lldb/main.lldbinit build\wincross\x86_64\debug\exec.exe
```

## Rules reference

All rule definitions are loaded by `includes("./xmake/rules/*.lua")`; enable
them per target with `add_rules("<name>")`.

### `vscode.compile_commands`

Generates `.vscode/compile_commands.json` once after configuration.

| Option               | Default   | Description                   |
| -------------------- | --------- | ----------------------------- |
| `--compile-commands` | `true`    | Set to `n` to skip generation |

```lua
add_rules("vscode.compile_commands")
```

```sh
xmake f --compile-commands=n
```

### `cxx.headerunit_dirs`

Keeps header-unit BMIs **per target** and exposes header directories for GCC.

Without it, xmake shares header-unit BMIs per mode (or uses `gcm.cache`), which
breaks targets using different language options such as `-fexceptions` or
`-frtti`. The rule relocates each header-unit BMI into the target's own module
cache and fixes GCC's include handling for header units in subdirectories.

No options.

```lua
add_rules("cxx.headerunit_dirs")
```

Recommended on every target that uses header units (`import <cstdio>;`).

### `cxx.scanner_norm`

Normalizes logical names produced by the C++ modules **fallback scanner**.
Aligned imports keep trailing padding (`import std   ;`, `import <cstdio> ;`),
which otherwise no longer matches the module that provides them. The rule
strips the padding before header lookup and after scanning.

No options.

```lua
add_rules("cxx.scanner_norm")
```

Use together with `set_policy("build.c++.modules.fallbackscanner", true)`.

### `embed_cxx`

Generates C headers, C++ headers or C++ module units from static files.

```lua
add_rules("embed_cxx")

set_values("embed.assets", {
    mode      = "header",          -- "header" | "module" | "c-header"
    namespace = "assets",          -- C++ only
    entries   = {
        {"logo",   "assets/logo.png"},
        {"config", "assets/config.json"},
    },
})
```

Every group is configured as `set_values("embed.<id>", {...})`.

| Key           | Type    | Default          | Description                                                  |
| ------------- | ------- | ---------------- | ------------------------------------------------------------ |
| `mode`        | string  | `"header"`       | `"header"`, `"module"` or `"c-header"`                       |
| `module`      | string  | `"embed.<id>"`   | Module unit name; only valid in `"module"` mode              |
| `namespace`   | string  | —                | C++ namespace wrapper; C++ only                              |
| `consteval`   | boolean | `false`          | Emit `consteval` accessors instead of plain arrays; C++ only |
| `incbin`      | boolean | `false`          | Copy bytes with the assembler (`.incbin`)                    |
| `embed_macro` | boolean | `false`          | Copy bytes with `#embed`                                     |
| `entries`     | list    | **required**     | List of `{name, path}` pairs                                 |
| `output`      | string  | mode-dependent   | Output filename                                              |
| `outdir`      | string  | generated dir    | Output directory                                             |
| `asm`         | string  | `"embed_<id>.S"` | Assembler filename; `incbin` only                            |

Default output names:

| Mode               | File                                        |
| ------------------ | ------------------------------------------- |
| `header`           | `embedded_<id>.hpp`                         |
| `module`           | `<module>.cppm` (default `embed.<id>.cppm`) |
| `c-header`         | `embedded_<id>.h`                           |
| `incbin` companion | `embed_<id>.S`                              |

Constraints (rejected at configure time):

- `incbin` and `embed_macro` are mutually exclusive.
- `incbin` cannot be combined with `consteval` (a `std::span` is already
  constexpr).
- `module` is only valid in `"module"` mode.
- `namespace` and `consteval` are only valid for C++ (`"c-header"` rejects them).
- `embed_macro` is rejected in `"module"` mode (it ICEs Clang modules).

Representation choices:

```lua
-- Hex literals (default): simple, but the whole payload is generated as text.
set_values("embed.small", {
    entries = {{"data", "data/small.bin"}},
})

-- #embed: tiny generated header, preprocessing copies the file.
set_values("embed.large", {
    mode        = "header",
    embed_macro = true,
    entries     = {{"data", "data/large.bin"}},
})

-- .incbin: best for very large payloads, copied verbatim by the assembler.
set_values("embed.font", {
    mode    = "header",
    namespace = "font",
    incbin  = true,
    entries = {{"noto", "assets/NotoColorEmoji.ttf"}},
})
```

The generated include directory is added to the target automatically. Module
units and `.S` companions are registered as target files.

### `payload_extract`

Extracts a section (or an address range inside it) from the built target with
`llvm-objcopy`/`objcopy`. It can generate a C header, C++ header or module, or
only write the raw `.bin`.

```lua
add_rules("payload_extract")

set_values("payload.cfg.code", {
    mode    = "header",       -- "header" | "module" | "c"
    section = ".text",
    strip   = true,
})
```

Multiple payloads are supported on the same target:

```lua
set_values("payload.cfg.code", {section = ".text"})
set_values("payload.cfg.data", {section = ".rodata", strip = true})
```

| Key            | Type    | Default                    | Description                                           |
| -------------- | ------- | -------------------------- | ----------------------------------------------------- |
| `mode`         | string  | `"header"`                 | `"header"`, `"module"` or `"c"`                       |
| `section`      | string  | `".text"`                  | Section to dump                                       |
| `addr`         | table   | —                          | `{start, end}` 0-based byte range; `end` is exclusive |
| `strip`        | boolean | `false`                    | Drop trailing fill bytes                              |
| `align`        | integer | —                          | Pad the result to this alignment                      |
| `fill_byte`    | integer | `0x00`                     | Byte used by `strip` and `align`                      |
| `only_gen_bin` | boolean | `false`                    | Write only the raw `.bin`; do not generate code       |
| `binfile`      | string  | `"<targetdir>/<name>.bin"` | Output path of the `.bin`                             |
| `namespace`    | string  | —                          | C++ namespace wrapper; C++ only                       |
| `consteval`    | boolean | `false`                    | Emit `consteval` accessors; C++ only                  |

Generated code goes to `<targetdir>/include/<name>.<ext>`:

| Mode     | Extension   |
| -------- | ----------- |
| `header` | `.hpp`      |
| `module` | `.cppm`     |
| `c`      | `.h`        |

The include directory is registered as an interface include directory, and its
path is stored in `payload.generated_dir`; dependents added with
`add_deps("<payload-target>")` inherit it automatically.

A zero-length placeholder is generated during `xmake f`. The real file is
written in `after_build`, so the LSP sees the header immediately and the next
build picks up the actual bytes.

Pair `only_gen_bin` with `embed_cxx` when you want to choose the final
representation yourself:

```lua
target("payload")
    set_kind("binary")
    add_rules("payload_extract")
    set_values("payload.cfg.code", {
        section      = ".text",
        only_gen_bin = true,
        binfile      = "build/gen/code.bin",
    })

target("app")
    add_rules("embed_cxx")
    set_values("embed.code", {
        mode    = "header",
        incbin  = true,
        entries = {{"code", "build/gen/code.bin"}},
    })
```

### `bundle.fetch`

Downloads and extracts a release bundle when any required file is missing.
It is a thin, validated wrapper around `lang.bundle`.

```lua
add_rules("bundle.fetch")

set_values("bundle.entries", bundle.fetch({
    url   = "https://github.com/example/project/releases/latest/download/bundle.tar.gz",
    dest  = ".",
    check = {"data/file.dat", "assets/font.ttf"},
}))
```

| Field          | Type        | Required   | Description                                                      |
| -------------- | ----------- | ---------- | ---------------------------------------------------------------- |
| `url`          | string      | yes        | Download URL or local path                                       |
| `dest`         | string      | yes        | Extraction directory                                             |
| `check`        | string/list | yes        | Files that must exist; the bundle is fetched when one is missing |
| `kind`         | string      | no         | `"file"` or `"archive"`; inferred from `url` when omitted        |
| `strip`        | integer     | no         | Leading path components to strip while extracting                |
| `only`         | string/list | no         | Extract only these archive members                               |
| `marker`       | string      | no         | Extra marker file                                                |
| `sha256`       | string      | no         | Expected 64-character hex digest                                 |
| `auth`         | string      | no         | `"gh"` to authenticate with the GitHub CLI                       |
| `check_strict` | boolean     | no         | Require every `check` entry (default `false`)                    |

`bundle.fetch` accepts one table or a list of tables:

```lua
set_values("bundle.entries", bundle.fetch({
    {url = ".../data.tar.gz", dest = "data", check = {"data/a.dat"}},
    {url = ".../assets.tar.gz", dest = "assets", check = {"assets/font.ttf"}},
}))
```

### Tasks

| Task                   | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `xmake pinfo [target]` | Print target info box(es); all targets when no name is given       |
| `xmake setup-perl`     | Validate/install Perl dependencies (requires a `lang.perl` module) |

`setup-perl` is only useful if you provide `lang.perl` yourself; it is not part
of this template.

## Extra flags and runtime arguments

The flag pipeline resets compiler/linker flags before applying its own, then
restores these additions:

| Method                           | Description                     |
| -------------------------------- | ------------------------------- |
| `add_cxflags(...)`               | Extra C/C++ flags               |
| `add_cflags(...)`                | Extra C flags                   |
| `add_cxxflags(...)`              | Extra C++ flags                 |
| `add_links(...)`                 | Extra libraries                 |
| `add_defines(...)`               | Extra preprocessor definitions  |
| `set("runargs", {...})`          | Arguments passed to the program |
| `set_values("run.detach", true)` | Run detached from `xmake run`   |

## Full example

```lua
set_project ("MyProject")
set_version ("1.0.0")
set_xmakever("3.0.0")

includes("./xmake/rules/*.lua")
add_repositories("local-repo ./xmake/")
add_moduledirs("./xmake/modules/")

set_policy("build.c++.modules"                , true)
set_policy("build.c++.modules.std"            , true)
set_policy("build.c++.modules.gcc.cxx11abi"   , true)
set_policy("build.c++.modules.fallbackscanner", true)
set_policy("build.c++.modules.reuse.strict"   , true)

-- Keep dictionary values intact (stock xmake treats a trailing table as
-- extra configuration).
_embed_orig_set_values = _embed_orig_set_values or set_values
function set_values(...)
    local args = {...}
    if #args == 2 then
        local name, value = args[1], args[2]
        if type(value) == "table" and table.is_dictionary(value) then
            return _embed_orig_set_values(name, value, {expand = false})
        end
    end
    return _embed_orig_set_values(...)
end

add_rules("vscode.compile_commands")
add_requires("lbyte.stx v0.4.0", {configs = {use_modules = true}})

target("app")
    set_default  (true    )
    set_languages("c++23" )
    set_kind     ("binary")
    set_basename ("app"   )

    add_rules("cxx.headerunit_dirs")
    add_rules("cxx.scanner_norm"   )

    add_files("src/main.cpp")
    add_packages("lbyte.stx")

    set_values("buildtype" , "native" )
    set_values("exceptions", true     )
    set_values("rtti"      , true     )
    set_values("run.detach", false    )
    set        ("runargs"  , {"--help"})

    add_links("m")
    add_defines("APP_BUILD=1")

    on_config  ("actions.configure"  )
    after_build("actions.after_build")
    on_run     ("actions.run_process")
```

## Modules and header units

The template keeps `build.c++.modules.fallbackscanner` enabled because the
fallback scanner is what makes cross-toolchain module builds predictable here.

- `cxx.headerunit_dirs` gives every target its own header-unit BMI. This is why
  `app` and `app2` can import `<cstdio>` while using different `-fexceptions` /
  `-frtti` settings.
- `cxx.scanner_norm` removes padding left by aligned imports before the scanner
  records dependency names.
- `actions.configure` clears a stale `cxxmodules` cache when the mode,
  toolchain, architecture or platform changes, and removes GCC's stray
  `gcm.cache` after configuration and after the build.

If builds ever look inconsistent after a manual toolchain switch, a clean
rebuild is still safe:

```sh
rm -rf .xmake build gcm.cache
xmake f --toolchain=clang -y
xmake build
```

## Local package repository

`xmake/packages/` is a local repository, enabled by:

```lua
add_repositories("local-repo ./xmake/")
```

### `lbyte.stx`

A C++23 utility library tracked by git tags:

```lua
add_requires("lbyte.stx v0.4.0", {configs = {use_modules = true}})

target("app")
    add_packages("lbyte.stx")
```

`use_modules = false` builds it as a header-only package.
New tags must be added to `add_versions` in
`xmake/packages/l/lbyte.stx/xmake.lua`.

## License

MIT. See [LICENSE](LICENSE).
