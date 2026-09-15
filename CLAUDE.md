# CLAUDE.md

Guidance for Claude Code (claude.ai/code) and other agents working in this repository.

## What this is

METIS 4.0.3 — serial graph/mesh partitioning and fill-reducing orderings, originally
from Karypis Lab at the University of Minnesota. This is CIBC's vendored fork, used as
an external dependency by the GPUTUM solvers (FEM, Eikonal, LevelSet).

Two things follow from "vendored fork of a 1998 C library", and they drive almost every
judgement call here:

1. **The code is pre-C99 and must stay buildable by modern compilers.** GCC 14 and
   Clang 16 promoted several long-standing warnings to errors by default. This project
   hit every one of them.
2. **It is a dependency, not an application.** Downstream consumers pin it and link it
   into larger builds (including HSL/IPOPT toolchains). Changing the public surface —
   exported symbols, the CMake target, header layout — breaks people silently.

## Layout

| Path | Contents |
|---|---|
| `Lib/` | The library. Everything compiled into `libmetis.a`. |
| `Programs/` | Standalone CLI drivers (`pmetis`, `kmetis`, `onmetis`, …). |
| `Test/` | `mtest.c`, a standalone API exerciser. |
| `Graphs/` | Sample inputs (`4elt.graph`, `metis.mesh`) plus a committed reference partition. |
| `Doc/` | Upstream manual. |

### Header include order is load-bearing

`Lib/metis.h` includes, in this order: `defs.h`, `struct.h`, `macros.h`, `rename.h`,
`proto.h`. `rename.h` must come before `proto.h`, because it `#define`s every internal
function to a `__`-prefixed name and the prototypes in `proto.h` have to be rewritten by
those macros. Reordering these silently unprefixes the whole library.

**Consequence:** a function added to `Lib/` needs entries in *both* `proto.h` and
`rename.h`, spelled identically. A mismatch between them does not fail loudly — it
produces an undeclared-function error at the call site and leaks an unprefixed symbol
into the archive. That exact typo (`SelectQueueoneWay` vs `SelectQueueOneWay`) shipped
in this repository for years.

### `Lib/io.c` vs `Programs/io.c`

Near-duplicates, and *not* interchangeable: `Lib/io.c` additionally defines
`partnmesh()`, a CIBC addition to the library API. `Lib/io.c` is the one that belongs in
`libmetis.a`. The CMake build links programs against the library copy rather than
recompiling `Programs/io.c`, which would collide at link time.

## Building

```sh
cmake -S . -B build -DMETIS_BUILD_PROGRAMS=ON
cmake --build build -j
.github/scripts/smoke-test.sh build
```

`METIS_BUILD_PROGRAMS` defaults to **OFF** on purpose: consumers who `add_subdirectory()`
this project expect exactly one target. Keep it that way.

`cmake_minimum_required` is a range (`3.10...3.31`). A bare minimum below 3.5 is rejected
outright by CMake 4.x. Don't lower it back to a single old value.

## Testing

`.github/scripts/smoke-test.sh <build-dir>` runs every program against `Graphs/` and
checks the partitions produced — vertex counts and part counts — not just exit status.

**A green build is not sufficient evidence that a change is correct here.** The defect
that motivated this test suite compiled perfectly cleanly and then corrupted the heap at
run time. Always run the smoke test, and prefer running it under sanitizers:

```sh
cmake -S . -B build-asan -DMETIS_BUILD_PROGRAMS=ON -DCMAKE_C_COMPILER=clang \
  -DCMAKE_C_FLAGS="-fsanitize=address,undefined -g -O1"
cmake --build build-asan -j
ASAN_OPTIONS=detect_leaks=0 .github/scripts/smoke-test.sh build-asan
```

Leak detection is off by convention: METIS 4.0.3 has pre-existing leaks that nobody has
fixed. Don't turn it on and then "fix" the resulting noise as part of an unrelated change.

If you add a check to the smoke test, verify it fails against a deliberately broken
build before trusting it. A check that cannot fail is worse than no check, because it
reads as coverage. `Graphs/` ships a committed `4elt.graph.part.10`, so the script
deletes stale partition files before running — otherwise a check passes on a file the
run never produced.

## Conventions

- **C89 declaration style.** Variables at the top of the function, before statements.
  CI enforces this with `-Werror=declaration-after-statement`. The repo has fixed this
  regression twice already (`22a4c66`, `c7b3350`).
- **No `bool`/`stdbool.h`.** Use `int` with `0`/`1`. `Programs/partnmesh.c` was broken
  for years by a stray `bool`.
- **Don't reformat.** This is vendored upstream code; whitespace churn makes it
  impossible to diff against the original tarball. Touch only what the change requires.
- **Prefer fixing a declaration over editing call sites.** `GKfree()`'s first parameter
  is `void*`, not `void**`, specifically so that 65 call sites passing `idxtype**` stay
  untouched and correct — `void**` is not a generic pointer type in C.

## Known issues, deliberately not fixed

Leave these alone unless you are explicitly fixing them, and expect CI to warn about
some of them:

- **`MAXIDX` in `Lib/struct.h`** is `((1<<8*sizeof(idxtype)-2))`. Because binary `-`
  binds tighter than `<<`, this evaluates to `1 << 30` (1073741824), not something near
  `INT_MAX`. It may or may not be what the author intended; it is a live upper bound on
  graph size, so changing it changes behaviour. Clang warns about it
  (`-Wshift-op-parentheses`). Don't "fix" it incidentally.
- **Memory leaks** throughout, as noted above.
- **`Programs/io.c`** is a stale near-duplicate of `Lib/io.c`.

## Scope discipline

This is somebody else's library, pinned by other projects. Prefer the smallest change
that fixes the reported problem. Modernising idioms, reformatting, or refactoring for
its own sake is not welcome here — it inflates the diff against upstream and raises the
cost of the next rebase for everyone downstream.
