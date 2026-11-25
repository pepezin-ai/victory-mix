# victory-mix

A tested mix of open work on running an **Xbox Series title natively on a Windows PC**, from files the user supplies: the `fxceless/victory-fork` main, open pull requests that were not merged yet, a few fixes of our own, and a simple launcher with presets.

> **Not playable yet.** The opening scene renders with characters, textures, sunlight and the area outside, at about **2 to 4 fps** on the machine below.

## Legal notice

- **This repository contains no game files, code or assets**, no keys, and no code, headers or binaries from the console SDK. You need your own legally obtained copy of the title.
- It works only on **unpacked game files you already own**. It does not download, decrypt or unpack game packages (XVC / MSIXVC) and contains nothing for circumventing DRM or any other protection.
- The game folder is only read. Saves, caches and logs go to `%LOCALAPPDATA%\victory-mix`.
- The Windows components it relies on (D3D12, DXGI, XAudio2, DXC) come from your own system or the public Windows SDK and are not distributed here.
- It is **not affiliated with or endorsed by** the title's developer or publisher, or by Microsoft. All trademarks belong to their owners and are not used in this repository.
- The goal is interoperability and preservation research on hardware you own. Do not use it to obtain, share or run copies you do not own, and do not open issues asking for game files or where to get them: such issues and links are removed.
- If you hold rights in something here and believe it should not be, please open an issue or contact the maintainer, and it will be reviewed and removed promptly.

The code is GPL-3.0-or-later, the license of VIctory and victory-fork it is built on.
## Status (2026-11-24)

**Not playable yet: about 2 to 4 frames per second, and shadowed areas are dark.**
Tested on one machine (see [Measured on](#measured-on)), Series X profile.

| Stage | State in victory-mix |
|---|---|
| Boot, menus, start screen | works, 30 fps (as upstream) |
| Opening cutscene | plays with subtitles; some shots still overexposed |
| First gameplay scene | renders: characters with skin and hair colour, textures, sunlight, cast shadows on walls, the area outside with people; HUD prompts and pad input work |
| Light in shadow | partly: ray-tracing programs now translate on NVIDIA (PR #156), but the bounce light is not wired up, so interiors stay dark |
| Frame rate in the world | 2.4-2.6 fps average, up to 3.9 (Quality preset) |
| Stability | no device loss in normal runs after the R9G9B9E5 fix; the first cold launch of a build can still lose the GPU while thousands of pipelines compile |
| Series S profile | black picture without the present fix (PR #188), not included yet |

## Roadmap: what is missing to be playable

Rough order of impact. Most of it is upstream work in VIctory and victory-fork; this mix picks it up as soon as it is tested.

| # | Missing | Why it matters | Where the work is |
|---|---|---|---|
| 1 | **Frame rate: 25-30+ fps** | Today about 300 ms per frame. Roughly half is host-side copies of title memory before each frame, a third is GPU time, the rest is copy back | copy and wait reductions (relay, in-place title memory, write-watch), the xboxmericavi switches; Linux-measured copy changes must be re-checked on Windows (PR #363) |
| 2 | **Lighting in shadow** | Interiors and anything out of direct sun are dark | ray-tracing bounce light and lamp/sun shadows: structure builder and 59 of 64 trace programs translate, nothing is lit by them yet |
| 3 | **Shader coverage** | Some world programs still do not translate, so their draws are dropped (missing details, pixel blocks on faces, overexposed shots) | open shader PRs (+46 programs in #203 is in; #52, #280, #123, #146, #235 conflict and are pending) |
| 4 | **Upscaling** | Rendering at native resolution costs most | host FSR/DLSS answering the title's upscale calls (VIctory PRs #1704, #1793) |
| 5 | **Series S profile** | Lower resolution, more fps on mid-range GPUs | present plane fix (PR #188) |
| 6 | **Memory** | Around 20+ GB in use during play | idle texture and cache eviction (in main), texture budgets |
| 7 | **Stability on more GPUs** | Verified on one NVIDIA card | reports from other GPUs; AMD has its own fork |
| 8 | **Full playthrough** | Only the opening scenes are tested | testing past the prologue: driving, open world streaming, missions, saves |
## What you get

| | |
|---|---|
| Base | [`fxceless/victory-fork`](https://github.com/fxceless/victory-fork) `main` (the code behind hyphennn's streams) |
| Ray tracing on NVIDIA (32-lane GPUs) | open PRs #156 and #213 |
| +46 shader programs (image quality) | open PR #203 |
| Crash fix when entering the world | R9G9B9E5 render-target stand-in (open PR #32) |
| Performance presets | AnyXboxX tuned settings (Quality) and the xboxmericavi TURBO switches (Turbo preset) |
| Launcher | `launcher\victory-mix.cmd`: pick your game folder, choose a preset, play; one log per run |

Everything else comes unchanged from the projects credited below.

## Requirements

- Windows 10/11, a DirectX 12 GPU. Tested on NVIDIA; AMD users should look at the AMD-focused forks.
- Rust (`winget install Rustlang.Rustup`) and Visual Studio Build Tools with the **C++ workload**.
- Your own copy of the game: the folder that contains `game_scarlett_master.exe`.

## Quick start

1. Clone this repository.
2. Double-click `launcher\victory-mix.cmd`.
3. The first time, it asks for your **game folder**. You can pick it in a window or paste the path. It is saved only on your PC, in `%LOCALAPPDATA%\victory-mix\config.json`.
4. The first launch builds the project (`cargo build --release -p victory`), which takes a few minutes.
5. Choose a preset. The screen stays **black for a few minutes** the first time, while shaders compile. They are cached for the next runs.
6. At the start screen press **A** on your controller. With a controller connected, the keyboard is ignored; without one, **Enter** acts as A.

Command line: `launcher\victory-mix.ps1 -Preset turbo` (or `quality`, `balanced`, `seriess`, `clean`), plus `-Build` to rebuild, `-DryRun` to only print what would run, and `-ResetConfig` to pick the game folder again.

## Presets

| Preset | For | Profile | Main variables |
|---|---|---|---|
| **Quality** (default) | Best image so far, ~2-4 fps | Series X | `VICTORY_HOST_WAVE=32`, loop limit 256, `LATE_WAIT=3`, `WIDE_BACK=1`, card buffers 1024 MB |
| **Turbo** | More fps; textures stream in more slowly | Series X | Quality + `RELAY=1`, texture budget 64 MB / 80 ms per frame, `TEXTURE_NO_WAIT`, `JOIN_COPIES`, 256 lists in flight; high CPU priority |
| **Balanced** | If Quality crashes on your GPU | Series X | Quality without `VICTORY_HOST_WAVE` |
| **Series S** (experimental) | Lower render resolution | Series S | Quality's variables. The picture is black on many GPUs without the Series S present fix (PR #188) |
| **Clean** | Bug reports and comparisons | Series X | none |

### What the variables do

| Variable | Effect |
|---|---|
| `VICTORY_HOST_WAVE=32` | Translates shaders for GPUs whose waves are at most 32 lanes (NVIDIA). Needed by the ray-tracing programs of PR #156 |
| `VICTORY_SHADER_LOOP_LIMIT=256` | Translated shader loops stop after 256 iterations. Lower values cut hair strand loops short; none can hang the GPU on some cards |
| `VICTORY_LATE_WAIT=3`, `VICTORY_WIDE_BACK=1` | Submit work ahead of the wait for the card, and copy back on several threads |
| `VICTORY_CARD_BUFFERS_MIN_MB`, `VICTORY_CARD_BUFFERS_MB` | Card buffer sizing |
| `VICTORY_RELAY=1` | A thread lands results as the card finishes them. Value 2 can drop characters' skin and overlap subtitles (fxceless issue #89) |
| `VICTORY_TEXTURE_STAGE_MB`, `VICTORY_TEXTURE_STAGE_MS` | Texture memory and time staged per frame (defaults 192 MB / 250 ms). Lower means faster frames and slower texture streaming |
| `VICTORY_TEXTURE_NO_WAIT`, `VICTORY_JOIN_COPIES`, `VICTORY_UNWATCHED_FRAMES`, `VICTORY_CARD_REHASH_RUNS`, `VICTORY_LATE_WAIT_LISTS` | The xboxmericavi TURBO set (see its README) |
| `VICTORY_SHADER_OPT=0` | Turns off the translated-shader clean-up passes (on by default) |

## Measured on

Windows 11, AMD Ryzen 7 5700X (8C/16T), 32 GB DDR4-3200, NVIDIA RTX 5070 12 GB. Same opening scene, warm shader cache, average of the frame lines with more than 1,000 draws:

| Build | World fps (avg / max) |
|---|---|
| fxceless + ray tracing PRs, Series X | 2.5-3.3 / 4.3 |
| **victory-mix** (newer main + #156 + #213 + #203), Quality | **2.4-2.6 / 3.9** |
| same + xboxmericavi patches and TURBO switches | 2.3 / 3.9 (no gain on this machine) |

## Known issues

- Series S profile (`--console series-s`): black picture unless the present fix (PR #188) is in; not included yet.
- First launch of each build can lose the GPU while thousands of pipelines compile. Launch again once the cache is filled.
- Areas in shadow are dark. The game's ray-traced bounce light does not run yet.
- PR #363 (copy changes measured on Linux/Proton) made copy back go from ~34 ms to ~3.6 s per frame on Windows here, so it is **not** included ([report](https://github.com/fxceless/victory-fork/pull/363#issuecomment-7149067082)).

## Credits

This mix only exists because of these people and projects. All the hard work is theirs:

- **[Marvisak/VIctory](https://github.com/Marvisak/VIctory)**, by Marvisak and its contributors: the base of everything. Loader, runtime services, the Direct3D 12 back end and the shader recompiler (GPL-3.0-or-later).
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)**, by fxceless (hyphennn): the rendering and speed fork this mix is built on, including the branches it took from **triippywhale** (AMD view-heap clamp) and **asdaasdsaddf** (double-precision shaders, DirectStorage retries, texture catch-up).
- **[XCL](https://github.com/ivall/xcl)**, by ivall and contributors: the reference fxceless used for how the title behaves under another layer.
- **[tadymila/xboxmericavi](https://github.com/tadymila/xboxmericavi)**: the TURBO switches used by the Turbo preset.
- **[LooperSalty/AnyXboxX](https://github.com/LooperSalty/AnyXboxX)**: the tuned launch settings (loop limit, late wait, card buffers) and the PR batches where we found the R9G9B9E5 fix.
- Pull requests included before their merge, with thanks to their authors:
  - [#156](https://github.com/fxceless/victory-fork/pull/156) by **@sedzz**: ray-tracing shadow traces and structure builder on 32-lane GPUs
  - [#213](https://github.com/fxceless/victory-fork/pull/213) by **@Pablo-Barros**: ray tracing, a missing child is a miss
  - [#203](https://github.com/fxceless/victory-fork/pull/203) by **@triippywhale**: +46 shader programs
  - [#32](https://github.com/fxceless/victory-fork/pull/32) by **@arminkhaleghirod**: 16-bit float RGBA stands in for R9G9B9E5 render targets
- Our part (**pepezin-ai**): picking, merging and testing the pieces, resolving the merge conflicts (#156 against the newer main), the launcher and its presets, and the measurements above.

Every commit keeps its original author; merges and cherry-picks are marked as such.
