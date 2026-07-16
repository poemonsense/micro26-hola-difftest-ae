#!/usr/bin/env python3

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results" / "raw"
SVM_SCALA = ROOT / "SVM" / "src" / "main" / "scala"
PERF_RE = re.compile(r"^\[PERF\]\s+([A-Za-z0-9_]+):\s+0x([0-9a-fA-F]+)\s*$")
SAMPLE_RE = re.compile(r"^\[\s*(\d+)\]\s+([A-Za-z0-9_]+):\s+(-?\d+)\s*$")


def read_text(path):
    if not path.is_file():
        raise FileNotFoundError(f"required result is missing: {path}")
    return path.read_text(encoding="utf-8", errors="ignore")


def hardware_counters(config_id):
    result_dir = RESULTS / config_id
    if not (result_dir / "success").is_file():
        raise FileNotFoundError(f"successful result is missing for {config_id}")
    parsed = {}
    for line in read_text(result_dir / "stdout.log").splitlines():
        match = PERF_RE.match(line)
        if match:
            parsed[match.group(1)] = int(match.group(2), 16)
    if not parsed:
        raise ValueError(f"firmware performance counters are missing from {config_id}")
    return parsed


def counter(values, config_id, name):
    if name not in values:
        raise ValueError(f"counter {name} is missing from {config_id}")
    return values[name]


def percent(numerator, denominator):
    if denominator == 0:
        raise ValueError("cannot compute a percentage with a zero denominator")
    return 100.0 * numerator / denominator


def fmt(value):
    if value is None:
        return "X"
    return f"{value:.2f}%"


def print_table(title, column_title, columns, rows):
    print(f"## {title}")
    print(" | ".join([column_title] + list(columns)))
    print(" | ".join(["---"] * (len(columns) + 1)))
    for label, values in rows:
        print(" | ".join([label] + [fmt(value) for value in values]))
    print()


def displayed_tables_match(measured_rows, paper_rows):
    if len(measured_rows) != len(paper_rows):
        return False
    for (measured_label, measured), (paper_label, paper) in zip(measured_rows, paper_rows):
        if measured_label != paper_label or len(measured) != len(paper):
            return False
        for actual, expected in zip(measured, paper):
            if (actual is None) != (expected is None):
                return False
            if actual is not None and fmt(actual) != fmt(expected):
                return False
    return True


def print_comparison(measured_rows, paper_rows):
    if displayed_tables_match(measured_rows, paper_rows):
        print(
            "**Comparison:** All measured values match the paper at the displayed "
            "precision (two decimal places)."
        )
    else:
        print(
            "**Comparison:** One or more measured values differ from the paper at "
            "the displayed precision."
        )


def raw_log(config_id, filename="stdout.log"):
    path = f"results/raw/{config_id}/{filename}"
    return f"[{path}](../{path})"


def hex_counter(value):
    return f"0x{value:016x}"


def ratio_calculation(numerator_name, numerator, denominator_name, denominator, value):
    return (
        f"100 x {numerator_name}({hex_counter(numerator)}) / "
        f"{denominator_name}({hex_counter(denominator)}) = {value:.6f}% -> {fmt(value)}"
    )


def print_provenance(entries, paper_source):
    print()
    print("## Measured data provenance")
    print("Point | Raw result | Calculation")
    print("--- | --- | ---")
    for point, source, calculation in entries:
        print(f"{point} | {source} | {calculation}")
    print()
    print("## Paper data provenance")
    print(
        f"{paper_source} The expected values are declared in "
        "[report/generate.py](../report/generate.py)."
    )


def figure11():
    sizes = [("256KB", "256k"), ("512KB", "512k"), ("1MB", "1m"), ("2MB", "2m")]
    ways = (4, 8, 16)
    measured = []
    provenance = []
    for size_label, size_id in sizes:
        row = []
        for way in ways:
            config_id = f"c{size_id}-w{way}-b4-p3-r0"
            if config_id == "c256k-w4-b4-p3-r0":
                result_dir = RESULTS / config_id
                if not (result_dir / "success").is_file():
                    raise FileNotFoundError(f"expected-abort result is missing for {config_id}")
                row.append(None)
                provenance.append(
                    (
                        f"{size_label}/{way}-way",
                        f"{raw_log(config_id)} and {raw_log(config_id, 'stderr.log')}",
                        "expected cache-capacity abort -> X",
                    )
                )
                continue
            values = hardware_counters(config_id)
            numerator = counter(values, config_id, "cache_evict_miss")
            denominator = counter(values, config_id, "cache_evict")
            value = percent(numerator, denominator)
            row.append(value)
            provenance.append(
                (
                    f"{size_label}/{way}-way",
                    raw_log(config_id),
                    ratio_calculation(
                        "cache_evict_miss", numerator, "cache_evict", denominator, value
                    ),
                )
            )
        measured.append((size_label, row))

    paper = [
        ("256KB", [None, 2.76, 3.42]),
        ("512KB", [0.60, 0.41, 0.36]),
        ("1MB", [0.06, 0.01, 0.00]),
        ("2MB", [0.02, 0.00, 0.00]),
    ]
    print("# Figure 11: evict miss rate")
    print("**Counter source:** hardware counters printed by firmware")
    print("**Metric:** 100 x cache_evict_miss / cache_evict")
    print()
    print_table("Measured", "Cache size", ["4-way", "8-way", "16-way"], measured)
    print_table("Paper", "Cache size", ["4-way", "8-way", "16-way"], paper)
    print_comparison(measured, paper)

    plru_id = "c256k-w8-b4-p3-r0-plru"
    plru = hardware_counters(plru_id)
    plru_numerator = counter(plru, plru_id, "cache_evict_miss")
    plru_denominator = counter(plru, plru_id, "cache_evict")
    plru_rate = percent(plru_numerator, plru_denominator)
    provenance.append(
        (
            "256KB/8-way PLRU",
            raw_log(plru_id),
            ratio_calculation(
                "cache_evict_miss",
                plru_numerator,
                "cache_evict",
                plru_denominator,
                plru_rate,
            ),
        )
    )
    print(f"**Supplementary 256KB 8-way PLRU:** {fmt(plru_rate)} (paper text: 0.53%)")
    print_provenance(
        provenance,
        "The Paper table is transcribed from paper Figure 11; the PLRU value is "
        "from its accompanying text.",
    )


def figure12():
    sizes = [("256KB", "256k"), ("512KB", "512k"), ("1MB", "1m"), ("2MB", "2m")]
    variants = ((2, 2), (2, 3), (4, 2), (4, 3))
    measured = []
    provenance = []
    for banks, ports in variants:
        row = []
        for size_label, size_id in sizes:
            config_id = f"c{size_id}-w8-b{banks}-p{ports}-r0"
            values = hardware_counters(config_id)
            numerator = counter(values, config_id, "core_out_miss")
            denominator = counter(values, config_id, "core_out")
            value = percent(numerator, denominator)
            row.append(value)
            provenance.append(
                (
                    f"{banks}-bank/{ports}-port, {size_label}",
                    raw_log(config_id),
                    ratio_calculation(
                        "core_out_miss", numerator, "core_out", denominator, value
                    ),
                )
            )
        measured.append((f"{banks}-bank, {ports}-port", row))

    paper = [
        ("2-bank, 2-port", [18.32, 2.08, 0.20, 0.19]),
        ("2-bank, 3-port", [18.18, 1.89, 0.02, 0.00]),
        ("4-bank, 2-port", [18.27, 2.00, 0.12, 0.11]),
        ("4-bank, 3-port", [18.18, 1.89, 0.01, 0.00]),
    ]
    columns = [label for label, _ in sizes]
    print("# Figure 12: instruction miss rate")
    print("**Counter source:** hardware counters printed by firmware")
    print("**Metric:** 100 x core_out_miss / core_out")
    print()
    print_table("Measured", "Configuration", columns, measured)
    print_table("Paper", "Configuration", columns, paper)
    print_comparison(measured, paper)
    print_provenance(
        provenance,
        "The Paper table is transcribed from paper Figure 12.",
    )


def figure13():
    sizes = [("256KB", "256k"), ("512KB", "512k"), ("1MB", "1m"), ("2MB", "2m")]
    disabled = []
    enabled = []
    overhead = []
    provenance = []
    for size_label, size_id in sizes:
        disabled_id = f"c{size_id}-w8-b2-p2-r0"
        enabled_id = f"c{size_id}-w8-b2-p2-r1"
        disabled_values = hardware_counters(disabled_id)
        enabled_values = hardware_counters(enabled_id)
        disabled_numerator = counter(disabled_values, disabled_id, "core_out_miss")
        disabled_denominator = counter(disabled_values, disabled_id, "core_out")
        disabled_value = percent(disabled_numerator, disabled_denominator)
        disabled.append(disabled_value)
        provenance.append(
            (
                f"disabled, {size_label}",
                raw_log(disabled_id),
                ratio_calculation(
                    "core_out_miss",
                    disabled_numerator,
                    "core_out",
                    disabled_denominator,
                    disabled_value,
                ),
            )
        )
        enabled_numerator = counter(enabled_values, enabled_id, "core_out_miss")
        enabled_denominator = counter(enabled_values, enabled_id, "core_out")
        enabled_value = percent(enabled_numerator, enabled_denominator)
        enabled.append(enabled_value)
        provenance.append(
            (
                f"enabled, {size_label}",
                raw_log(enabled_id),
                ratio_calculation(
                    "core_out_miss",
                    enabled_numerator,
                    "core_out",
                    enabled_denominator,
                    enabled_value,
                ),
            )
        )
        overhead_numerator = counter(enabled_values, enabled_id, "cache_read_cache_miss")
        refill = counter(enabled_values, enabled_id, "cache_refill")
        evict = counter(enabled_values, enabled_id, "cache_evict")
        overhead_value = percent(overhead_numerator, refill + evict)
        overhead.append(overhead_value)
        provenance.append(
            (
                f"overhead, {size_label}",
                raw_log(enabled_id),
                f"100 x cache_read_cache_miss({hex_counter(overhead_numerator)}) / "
                f"(cache_refill({hex_counter(refill)}) + cache_evict({hex_counter(evict)})) "
                f"= {overhead_value:.6f}% -> {fmt(overhead_value)}",
            )
        )

    measured = [("disabled", disabled), ("enabled", enabled), ("overhead", overhead)]
    paper = [
        ("disabled", [18.32, 2.08, 0.20, 0.19]),
        ("enabled", [0.70, 0.26, 0.19, 0.19]),
        ("overhead", [2.70, 0.41, 0.00, 0.00]),
    ]
    columns = [label for label, _ in sizes]
    print("# Figure 13: refill-on-read-miss impact")
    print("**Counter source:** hardware counters printed by firmware")
    print("**Miss metric:** 100 x core_out_miss / core_out")
    print("**Bandwidth overhead metric:** 100 x cache_read_cache_miss / (cache_refill + cache_evict)")
    print()
    print_table("Measured", "Series", columns, measured)
    print_table("Paper", "Series", columns, paper)
    print_comparison(measured, paper)
    print_provenance(
        provenance,
        "The Paper table is transcribed from paper Figure 13.",
    )


def sample_summary(config_id):
    path = RESULTS / config_id / "stderr.log"
    cycles = set()
    names = set()
    for line in read_text(path).splitlines():
        match = SAMPLE_RE.match(line)
        if match:
            cycles.add(int(match.group(1)))
            names.add(match.group(2))
    required = {"core_out", "core_out_load_store", "core_out_miss"}
    missing = sorted(required - names)
    if missing:
        raise ValueError(f"{config_id} is missing sampled counters: {', '.join(missing)}")
    if len(cycles) < 100:
        raise ValueError(f"{config_id} has too few counter snapshots: {len(cycles)}")
    return len(cycles), min(cycles), max(cycles)


def figure14():
    two_id = "c512k-w8-b2-p2-r1-sim"
    three_id = "c512k-w8-b4-p3-r1"
    two = sample_summary(two_id)
    three = sample_summary(three_id)
    pdf = ROOT / "evaluation" / "figure14.pdf"
    if not pdf.is_file() or pdf.stat().st_size == 0:
        raise FileNotFoundError(f"Figure 14 PDF is missing: {pdf}")
    print("# Figure 14: phased instruction miss rate and IPC during Linux boot")
    print("**Counter source:** periodic simulator counter snapshots")
    print("**RCache:** 512KB, 8-way, refill-on-read-miss")
    print("**Ports:** 2-port uses 2 banks; 3-port uses 4 banks")
    print("**Plot series:** 2-port miss rate, 3-port miss rate, IPC, IPC_lsu")
    print(f"**2-port snapshots:** {two[0]} (cycles {two[1]} through {two[2]})")
    print(f"**3-port snapshots:** {three[0]} (cycles {three[1]} through {three[2]})")
    print(
        f"**PDF:** [evaluation/figure14.pdf](figure14.pdf) "
        f"({pdf.stat().st_size} bytes)"
    )
    print()
    print("## Measured data provenance")
    print("Series | Simulator log | Calculation for each raw interval")
    print("--- | --- | ---")
    print(
        f"2-port miss rate | {raw_log(two_id, 'stderr.log')} | "
        "100 x delta(core_out_miss) / delta(core_out)"
    )
    print(
        f"3-port miss rate | {raw_log(three_id, 'stderr.log')} | "
        "100 x delta(core_out_miss) / delta(core_out)"
    )
    print(f"IPC | {raw_log(two_id, 'stderr.log')} | delta(core_out) / delta(cycle)")
    print(f"IPC_lsu | {raw_log(two_id, 'stderr.log')} | delta(core_out_load_store) / delta(cycle)")
    print(
        "[SVM/scripts/plot.py](../SVM/scripts/plot.py) aggregates up to 64 "
        "adjacent raw intervals per plotted point by summing their deltas."
    )
    print()
    print("## Paper data provenance")
    print(
        "The configurations and four displayed series are taken from paper "
        "Figure 14; it has no numeric Paper table."
    )


def lines(path):
    return read_text(path).splitlines()


def strip_trailing_blank(source):
    result = list(source)
    while result and not result[-1].strip():
        result.pop()
    return result


def remove_instrumentation(source, markers, remove_blank_before=()):
    result = []
    for line in source:
        if any(marker in line for marker in markers):
            if any(marker in line for marker in remove_blank_before):
                if result and not result[-1].strip():
                    result.pop()
            continue
        result.append(line)
    return result


def table4_counts():
    mmu = remove_instrumentation(
        lines(SVM_SCALA / "MMU.scala"),
        ["outs.head.bits.uop.bits.flags.is_mmu :="],
    )

    fetch_all = lines(SVM_SCALA / "Fetch.scala")
    fetch_boundary = next(
        index for index, line in enumerate(fetch_all) if line.startswith("// Source:")
    )
    fetch = strip_trailing_blank(fetch_all[:fetch_boundary])

    lsu_all = lines(SVM_SCALA / "LSU.scala")
    agu_start = next(index for index, line in enumerate(lsu_all) if line.startswith("class AGU("))
    agu = strip_trailing_blank(lsu_all[agu_start:])
    lsu = strip_trailing_blank(lsu_all[:agu_start])
    lsu_markers = [
        "io.out.bits.uop.bits.flags.is_load_store :=",
        "io.out.bits.uop.bits.flags.is_load_store := io.in.bits",
    ]
    lsu = remove_instrumentation(
        lsu,
        lsu_markers,
        remove_blank_before=["io.out.bits.uop.bits.flags.is_load_store := io.in.bits"],
    )

    core = remove_instrumentation(
        lines(SVM_SCALA / "Core.scala"),
        [
            'flags.is_mmu, "core_out_mmu"',
            'flags.is_load_store, "core_out_load_store"',
        ],
    )

    return [
        ("MMU", len(mmu), "MMU.scala", "MMU, IMMU, DMMU, MMUExpect, Sv39Trans, AddrTransInfo, PTEInterpreter"),
        ("FETCH", len(fetch), "Fetch.scala", "FETCH"),
        ("AGU", len(agu), "LSU.scala", "AGU, LAGU, SAGU"),
        ("LSU", len(lsu), "LSU.scala", "LSUOpcode, LSU, LoadUnit, StoreUnit"),
        ("ARITH", len(lines(SVM_SCALA / "Arithmetic.scala")), "Arithmetic.scala", "Arithmetic"),
        ("PRIV", len(lines(SVM_SCALA / "Privileged.scala")), "Privileged.scala", "Privileged"),
        ("TRAP", len(lines(SVM_SCALA / "Trap.scala")), "Trap.scala", "TRAP"),
        ("COMMIT", len(lines(SVM_SCALA / "Commit.scala")), "Commit.scala", "COMMIT"),
        ("RCore", len(core), "Core.scala", "PipelineStage, PipelineConnect, RCore"),
    ]


def table4():
    values = table4_counts()
    expected = [253, 61, 52, 126, 87, 154, 49, 25, 129]
    actual = [value[1] for value in values]
    if actual != expected:
        raise ValueError(f"Table 4 source boundaries changed: got {actual}, expected {expected}")
    print("# Table 4: lines of Chisel code for RCore modules")
    print("**Counting method:** physical source lines in the paper-listed class definitions.")
    print()
    print("Module | LoC | Source | Class definition")
    print("--- | --- | --- | ---")
    for module, count, source, definitions in values:
        source_path = f"SVM/src/main/scala/{source}"
        print(f"{module} | {count} | [{source_path}](../{source_path}) | {definitions}")
    print(f"Total | {sum(actual)} | - | -")


COMMANDS = {
    "figure11": figure11,
    "figure12": figure12,
    "figure13": figure13,
    "figure14": figure14,
    "table4": table4,
}


def main():
    parser = argparse.ArgumentParser(description="Generate MICRO 2026 AE reports")
    parser.add_argument("report", choices=COMMANDS)
    args = parser.parse_args()
    COMMANDS[args.report]()


if __name__ == "__main__":
    main()
