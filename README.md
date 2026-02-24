# security-qa-playbook

A Foundry-based **security QA playbook** repo: layered tests + reusable testkit + debugging guidance.
Goal: make smart-contract security testing **team-maintainable** and **easy to debug**.

> Focus: unit / integration / fork / invariant / differential testing patterns, plus common mocks + helpers.

---

## Quick Start

### Prerequisites
- Foundry installed: `forge`, `cast`, `anvil`
- (Optional) `bash` for scripts

### Install deps
This repo recommends **not committing `lib/`**. Install dependencies locally:

```bash
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Generate remappings
forge remappings > remappings.txt
```

### Run tests
```bash
forge test -vvv
```

### Run one-click CI script (local)
```bash
chmod +x scripts/ci.sh
./scripts/ci.sh
```

---

## Repo Layout

```text
security-qa-playbook/
├── src/
│   ├── mocks/             # controllable mocks for security testing
│   ├── testkit/           # reusable infra (accounts/units/asserts/fixtures/fork/trace)
│   ├── examples/          # minimal runnable business examples
│   └── interfaces/        # minimal interfaces (optional)
├── test/
│   ├── helpers/           # BaseTest / Asserts / Fixtures ...
│   ├── templates/         # copy-paste specs (training deliverables)
│   ├── unit/              # single-contract behavior
│   ├── integration/       # multi-contract compositions (mock + example)
│   ├── invariant/         # invariants & handler-based fuzzing
│   ├── differential/      # vuln vs fixed / before vs after diff tests
│   └── fork/              # mainnet fork regression (readonly first)
├── docs/
│   ├── playbook/          # methodology, debugging, PR bar
│   └── checklists/        # risk-driven test checklists
└── scripts/               # fmt/test/coverage automation
```

---

## Week 1 Deliverables (Engineering the Testing System)

- D1: test layering directories (`unit/integration/fork/invariant`)
- D2: unified `BaseTest` + role accounts (alice/bob/attacker/admin)
- D3: assert helpers (abs/rel/range)
- D4: unified fixtures (deploy & initialize)
- D5: debugging playbook: `docs/playbook/debugging-trace.md`
- D6: one-click script: `scripts/ci.sh`

See: `docs/playbook/debugging-trace.md` for tracing/logging/min-repro workflow.

---

## Fork Testing (Optional)

To run fork tests, set RPC endpoint:

```bash
export ETH_RPC_URL="https://..."
```

Then run fork suite (example):

```bash
forge test --match-path test/fork/*.t.sol -vvv
```

---

## Conventions

### Naming
- Tests: `test_<behavior>_<expected>()`
- Templates/spec: `*.spec.t.sol`
- Invariants: `*.invariant.t.sol`

### PR Quality Bar (suggested)
- `forge fmt --check`
- `forge test -vvv`
- `forge coverage` (optional gate)
- Add regression test for any bug fix

---

## FAQ

### Should we commit `lib/`?
Recommendation: **No**. Keep repo clean and reproducible by running `forge install`.
If your environment is air-gapped, consider committing `lib/` or pinning deps via internal mirrors.

---

## License
MIT (or choose your preferred license).
