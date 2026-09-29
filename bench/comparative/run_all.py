from __future__ import annotations

import csv
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


BUILD_DIR = Path(__file__).resolve().parent / "build"
RESULTS_DIR = Path(__file__).resolve().parent / "results"

EXPECTED_CHECKSUMS = {
    2: 26_756_370_240,
    3: 324_207_267_022_400,
    4: -324_207_267_022_400,
}

REQUIRED_CASES = (
    "direct2",
    "pipe2",
    "compose2",
    "direct3",
    "pipe3",
    "compose3",
    "direct4",
    "pipe4",
    "compose4",
)

EXPECTED_LANGUAGES = (
    "Nim-ARC",
    "Nim-ORC",
    "Haskell",
    "Elixir",
    "F#",
    "OCaml",
)

RESULT_PATTERN = re.compile(
    r"^RESULT,"
    r"(?P<language>[^,]+),"
    r"(?P<case>[^,]+),"
    r"(?P<ns>[0-9]+(?:\.[0-9]+)?),"
    r"(?P<checksum>-?[0-9]+)$"
)


@dataclass(frozen=True)
class Result:
    language: str
    case: str
    ns_per_op: float
    checksum: int


@dataclass(frozen=True)
class BenchmarkTarget:
    name: str
    compile_command: list[str] | None
    run_command: list[str]


DIRECT_NAMES = {
    2: "direct2",
    3: "direct3",
    4: "direct4",
}

PIPE_NAMES = {
    2: "pipe2",
    3: "pipe3",
    4: "pipe4",
}

COMPOSE_NAMES = {
    2: "compose2",
    3: "compose3",
    4: "compose4",
}


def require_command(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(
            f"Required command not found: {name}"
        )


def run_process(
    command: list[str],
    *,
    cwd: Path,
) -> str:
    print()
    print("$", " ".join(command))
    print()

    process = subprocess.Popen(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )

    if process.stdout is None:
        process.kill()
        raise RuntimeError(
            "Failed to capture benchmark output."
        )

    output: list[str] = []

    for line in process.stdout:
        print(line, end="")
        output.append(line)

    return_code = process.wait()

    if return_code != 0:
        raise RuntimeError(
            f"Benchmark command failed with exit code "
            f"{return_code}: "
            + " ".join(command)
        )

    return "".join(output)


def parse_results(
    output: str,
) -> list[Result]:
    results: list[Result] = []

    for line in output.splitlines():
        match = RESULT_PATTERN.match(line.strip())

        if match is None:
            continue

        results.append(
            Result(
                language=match.group("language"),
                case=match.group("case"),
                ns_per_op=float(
                    match.group("ns")
                ),
                checksum=int(
                    match.group("checksum")
                ),
            )
        )

    return results


def validate_results(
    results: list[Result],
) -> None:
    if not results:
        raise RuntimeError(
            "Benchmark produced no RESULT records."
        )

    expected_count = (
        len(EXPECTED_LANGUAGES)
        * len(REQUIRED_CASES)
    )

    if len(results) != expected_count:
        raise RuntimeError(
            f"Expected {expected_count} RESULT records, "
            f"got {len(results)}."
        )

    expected_keys = {
        (language, case)
        for language in EXPECTED_LANGUAGES
        for case in REQUIRED_CASES
    }

    actual_keys = {
        (result.language, result.case)
        for result in results
    }

    if actual_keys != expected_keys:
        missing = sorted(
            expected_keys - actual_keys
        )
        unexpected = sorted(
            actual_keys - expected_keys
        )

        raise RuntimeError(
            f"Result-key mismatch. "
            f"Missing={missing}, "
            f"Unexpected={unexpected}"
        )

    if len(actual_keys) != len(results):
        raise RuntimeError(
            "Duplicate RESULT records detected."
        )

    for result in results:
        if result.ns_per_op <= 0.0:
            raise RuntimeError(
                f"Invalid ns/op for "
                f"{result.language}/{result.case}: "
                f"{result.ns_per_op}"
            )

        stage = int(result.case[-1])
        expected = EXPECTED_CHECKSUMS[stage]

        if result.checksum != expected:
            raise RuntimeError(
                f"{result.language} {result.case} "
                f"checksum mismatch: "
                f"expected {expected}, "
                f"got {result.checksum}"
            )


def ops_per_second(
    ns_per_op: float,
) -> float:
    return 1_000_000_000.0 / ns_per_op


def overhead_percent(
    direct_ns: float,
    other_ns: float,
) -> float:
    return (
        (other_ns / direct_ns) - 1.0
    ) * 100.0


def efficiency_percent(
    direct_ns: float,
    other_ns: float,
) -> float:
    return (
        direct_ns / other_ns
    ) * 100.0


def format_performance_table(
    results: list[Result],
) -> str:
    by_key = {
        (result.language, result.case): result
        for result in results
    }

    lines = [
        "| Language | Stage | Direct ns/op | Pipe ns/op | Pipe ops/s | Compose ns/op | Compose ops/s |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]

    for language in EXPECTED_LANGUAGES:
        for stage in (2, 3, 4):
            direct = by_key[
                (
                    language,
                    DIRECT_NAMES[stage],
                )
            ]
            pipe = by_key[
                (
                    language,
                    PIPE_NAMES[stage],
                )
            ]
            compose = by_key[
                (
                    language,
                    COMPOSE_NAMES[stage],
                )
            ]

            lines.append(
                "| "
                f"{language} | "
                f"{stage} | "
                f"{direct.ns_per_op:.3f} | "
                f"{pipe.ns_per_op:.3f} | "
                f"{ops_per_second(pipe.ns_per_op):,.0f} | "
                f"{compose.ns_per_op:.3f} | "
                f"{ops_per_second(compose.ns_per_op):,.0f} |"
            )

    return "\n".join(lines)


def format_efficiency_table(
    results: list[Result],
) -> str:
    by_key = {
        (result.language, result.case): result
        for result in results
    }

    lines = [
        "| Language | Stage | Pipe overhead | Pipe efficiency | Compose overhead | Compose efficiency |",
        "|---|---:|---:|---:|---:|---:|",
    ]

    for language in EXPECTED_LANGUAGES:
        for stage in (2, 3, 4):
            direct = by_key[
                (
                    language,
                    DIRECT_NAMES[stage],
                )
            ]
            pipe = by_key[
                (
                    language,
                    PIPE_NAMES[stage],
                )
            ]
            compose = by_key[
                (
                    language,
                    COMPOSE_NAMES[stage],
                )
            ]

            lines.append(
                "| "
                f"{language} | "
                f"{stage} | "
                f"{overhead_percent(direct.ns_per_op, pipe.ns_per_op):+.2f}% | "
                f"{efficiency_percent(direct.ns_per_op, pipe.ns_per_op):.2f}% | "
                f"{overhead_percent(direct.ns_per_op, compose.ns_per_op):+.2f}% | "
                f"{efficiency_percent(direct.ns_per_op, compose.ns_per_op):.2f}% |"
            )

    return "\n".join(lines)


def write_csv(
    results: list[Result],
    path: Path,
) -> None:
    with path.open(
        "w",
        newline="",
        encoding="utf-8",
    ) as handle:
        writer = csv.writer(handle)

        writer.writerow(
            [
                "language",
                "case",
                "ns_per_op",
                "ops_per_second",
                "checksum",
            ]
        )

        for result in results:
            writer.writerow(
                [
                    result.language,
                    result.case,
                    f"{result.ns_per_op:.9f}",
                    f"{ops_per_second(result.ns_per_op):.3f}",
                    result.checksum,
                ]
            )


def write_markdown(
    results: list[Result],
    path: Path,
) -> None:
    content = (
        "# Comparative Benchmark Results\n\n"
        "## Performance\n\n"
        + format_performance_table(results)
        + "\n\n"
        "## Efficiency Relative to Direct Baseline\n\n"
        + format_efficiency_table(results)
        + "\n"
    )

    path.write_text(
        content,
        encoding="utf-8",
    )


def make_targets(
    repo_root: Path,
) -> list[BenchmarkTarget]:
    comparative = (
        repo_root
        / "bench"
        / "comparative"
    )

    BUILD_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    nim_source = (
        comparative
        / "nim_piper.nim"
    )

    haskell_source = (
        comparative
        / "haskell"
        / "main.hs"
    )

    elixir_source = (
        comparative
        / "elixir"
        / "benchmark.exs"
    )

    fsharp_source = (
        comparative
        / "fsharp"
        / "benchmark.fsx"
    )

    ocaml_source = (
        comparative
        / "ocaml"
        / "benchmark.ml"
    )

    ocaml_stubs = (
        comparative
        / "ocaml"
        / "monotonic_stubs.c"
    )

    return [
        BenchmarkTarget(
            name="Nim-ARC",
            compile_command=[
                "nim",
                "c",
                "-d:release",
                "-d:danger",
                "--opt:speed",
                "--mm:arc",
                "--path:src",
                "-o:" + str(
                    BUILD_DIR / "nim_arc"
                ),
                str(nim_source),
            ],
            run_command=[
                str(
                    BUILD_DIR / "nim_arc"
                )
            ],
        ),
        BenchmarkTarget(
            name="Nim-ORC",
            compile_command=[
                "nim",
                "c",
                "-d:release",
                "-d:danger",
                "--opt:speed",
                "--mm:orc",
                "--path:src",
                "-o:" + str(
                    BUILD_DIR / "nim_orc"
                ),
                str(nim_source),
            ],
            run_command=[
                str(
                    BUILD_DIR / "nim_orc"
                )
            ],
        ),
        BenchmarkTarget(
            name="Haskell",
            compile_command=[
                "ghc",
                "-O2",
                "-fno-cse",
                "-fno-full-laziness",
                "-v0",
                "-o",
                str(
                    BUILD_DIR / "haskell"
                ),
                str(haskell_source),
            ],
            run_command=[
                str(
                    BUILD_DIR / "haskell"
                ),
                "0",
            ],
        ),
        BenchmarkTarget(
            name="Elixir",
            compile_command=None,
            run_command=[
                "elixir",
                str(elixir_source),
            ],
        ),
        BenchmarkTarget(
            name="F#",
            compile_command=None,
            run_command=[
                "dotnet",
                "fsi",
                "--optimize+",
                str(fsharp_source),
            ],
        ),
        BenchmarkTarget(
            name="OCaml",
            compile_command=[
                "ocamlopt",
                "-O3",
                "unix.cmxa",
                str(ocaml_source),
                str(ocaml_stubs),
                "-o",
                str(
                    BUILD_DIR / "ocaml"
                ),
            ],
            run_command=[
                str(
                    BUILD_DIR / "ocaml"
                )
            ],
        ),
    ]


def required_commands(
    target: BenchmarkTarget,
) -> list[str]:
    commands: set[str] = set()

    if target.compile_command:
        commands.add(
            target.compile_command[0]
        )

    run_command = target.run_command[0]

    if "/" not in run_command:
        commands.add(run_command)

    return sorted(commands)


def main() -> int:
    repo_root = (
        Path(__file__)
        .resolve()
        .parents[2]
    )

    targets = make_targets(
        repo_root
    )

    for target in targets:
        for command in required_commands(target):
            require_command(command)

    all_results: list[Result] = []

    for target in targets:
        print()
        print("=" * 72)
        print(target.name)
        print("=" * 72)

        if target.compile_command is not None:
            run_process(
                target.compile_command,
                cwd=repo_root,
            )

        output = run_process(
            target.run_command,
            cwd=repo_root,
        )

        parsed = parse_results(output)

        if target.name.startswith("Nim-"):
            parsed = [
                Result(
                    language=target.name,
                    case=result.case,
                    ns_per_op=result.ns_per_op,
                    checksum=result.checksum,
                )
                for result in parsed
            ]

        all_results.extend(parsed)

    validate_results(
        all_results
    )

    RESULTS_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    csv_path = (
        RESULTS_DIR
        / "latest.csv"
    )

    markdown_path = (
        RESULTS_DIR
        / "latest.md"
    )

    write_csv(
        all_results,
        csv_path,
    )

    write_markdown(
        all_results,
        markdown_path,
    )

    print()
    print("=" * 72)
    print("PERFORMANCE")
    print("=" * 72)
    print()
    print(
        format_performance_table(
            all_results
        )
    )

    print()
    print("=" * 72)
    print("EFFICIENCY RELATIVE TO DIRECT BASELINE")
    print("=" * 72)
    print()
    print(
        format_efficiency_table(
            all_results
        )
    )

    print()
    print(
        f"CSV: {csv_path}"
    )
    print(
        f"Markdown: {markdown_path}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
