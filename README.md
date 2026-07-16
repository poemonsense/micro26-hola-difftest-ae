# HOLA MICRO 2026 Artifact Evaluation

This repository reproduces Section 6.2 Figures 11-14 and Table 4 from the
submitted HOLA paper. All hardware experiments use the NutShell Verilator
simulator; no FPGA or Palladium access is required.

The paper manuscript is intentionally not bundled with the artifact. The
expected values and comparison criteria needed for evaluation are self-contained
in [ae.tex](ae.tex) and the generated reports.

## Get the artifact

```bash
git clone --recursive https://github.com/poemonsense/micro26-hola-difftest-ae
cd micro26-hola-difftest-ae
```

## One-command workflow

Clone the repository recursively, enter the supplied Ubuntu 24.04 container,
and run:

```bash
./run-all.sh
```

The command installs missing dependencies, builds every isolated emulator,
runs the Linux workload, and writes:

- `evaluation/figure11.txt`
- `evaluation/figure12.txt`
- `evaluation/figure13.txt`
- `evaluation/figure14.txt`
- `evaluation/figure14.pdf`
- `evaluation/table4.txt`

Detailed Docker commands, expected data, resource estimates, individual-stage
commands, and customization options are in [ae.tex](ae.tex).

## Individual stages

```bash
bash setup/setup.sh
bash build/build.sh
bash run/run.sh
bash report/report.sh
```

Builds are serialized and isolated below `build/build-*`. Simulator runs are
independent and use four parallel jobs by default. Set `AE_RUN_JOBS` to match
the available CPU and memory resources.
