# Oathbound — Agent ID Hackathon Plan

*"Promise bonds for AI agents."*

Living spec for the BNB Chain × Binance Wallet Agent ID Hackathon entry.
Repo: `cipoklean/oathbound` (link pending).
Last updated: 2026-11-21.

## Deadlines & eligibility

- Submissions close **2026-12-09 08:00 UTC**.
- Contracts must be deployed on **BNB Chain mainnet**, source **verified + open-sourced on BscScan**.
- **Innovation award:** ≥30 distinct Agent ID holder addresses must interact with our contracts during the submission window. Real users only — no fake accounts or volume inflation.

## Architecture (v1)

### PromiseBond.sol

- `declarePromise(bytes32 taskHash, address counterparty, uint256 deadline)` — payable.
  - Stake is **optional**: 0-stake promises count for reputation only; an
    attached BNB bond is an upgrade, not a requirement.
  - `counterparty` must hold an Agent ID (`balanceOf(counterparty) > 0`) and
    must be `!= msg.sender`. Revert otherwise.
- `attest(uint256 promiseId)` — callable only by the named counterparty, and
  only while `block.timestamp <= deadline`. Releases the stake back to the
  promiser and records a kept promise (+ `bondedKept` if stake > 0).
  After the deadline it reverts — `expire()` is the only remaining path.
- `expire(uint256 promiseId)` — permissionless, callable by anyone strictly
  after the deadline if unattested. Stake (if any) is burned to
  `0x0000...dEaD` and a broken promise is recorded. **Nothing ever
  auto-transfers to a third-party address.**
- **No cancellation.** A declared promise resolves only through `attest` or
  `expire`.

### AgentReputation.sol

- Per-agent counters: `kept`, `broken`, `bondedKept` (kept promises with
  stake > 0).
- `scoreOf(address)` returns `(kept, broken, bondedKept, scoreBps)` where
  `scoreBps = kept * 10000 / (kept + broken)`, and `0` when there is no
  history. Simple, readable on-chain; the site presents it however it likes.
- Reputation is keyed by **address** (not handle), per the red line below.

### Agent ID gate

- Gate on `IERC721(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F).balanceOf(a) > 0`
  (SPACE ID Agent ID, ERC-721, non-transferable) — applied to `declarePromise`
  (promiser) and counterparty validation.
- v1 uses `balanceOf` only. Do **not** rely on the handle→keccak256→ownerOf
  path until it is verified against a BSC mainnet fork.

### Events (for the website)

- `PromiseDeclared(promiseId, promiser, counterparty, taskHash, deadline, stake)`
- `PromiseAttested(promiseId, ...)`
- `PromiseExpired(promiseId, stakeBurned)`

Ship the ABI so the site can render live promises and scores.

### Agentic Wallet skill

- Lets an agent declare, attest, and check scores in plain language.
- Every bonded transaction goes through the user's normal wallet confirmation.
- No prompt or flow that bypasses confirmation.

### Immutability

- **No owner, no pause, no upgradeability, no admin functions of any kind.**
  Contracts are immutable at deploy. Stated plainly in README + NatSpec —
  it's the cleanest answer to the owner-permissions red line.

## Known limitations (document in README)

- **Collusion farming:** two cooperating Agent ID holders can attest each
  other's promises to farm kept counts at zero cost (especially 0-stake
  promises). Accepted for v1 — reputation is only meaningful when the
  counterparty has independent incentives. Mitigation path: staked dispute
  panels (roadmap).
- `scoreBps` treats 0-stake and bonded promises alike in the ratio;
  `bondedKept` is exposed so consumers can weight it themselves.
- Reputation is per-address, so an agent that gets a new wallet starts over
  (acceptable: Agent ID is non-transferable and one-per-user).

## Out of scope for v1 (roadmap pitch only)

- Dispute/arbitration panels
- Mutual-stake gig escrow
- Credit underwriting
- HeartbeatHub liveness / agent-will succession
- Shared reputation-registry-as-dependency play

## Hackathon red lines → our compliance

| Red line | How we comply |
|---|---|
| No QR/pairing-code Agentic Wallet login; no server-stored sessions acting for users | Site + skill only *prepare* transactions; user confirms in their own wallet |
| No automatic/hidden transfers; no unlimited approvals | `expire()` burns to 0xdead only; no pulls, no `approve` flow at all |
| Owner permissions documented; owner powers minimal | **Zero owner powers** — immutable, non-upgradeable; README + NatSpec state this |
| No "Binance"/"BNB" in project, token, or domain names | Name confirmed: **Oathbound** (tagline: "Promise bonds for AI agents") — no .bnb or Binance-style suffixes anywhere |
| No looking up another agent's wallet by name | `scoreOf(address)`; UI keys on address, no name search |
| No collecting seed phrases, keys, API secrets, pairing codes | Contracts take calldata only; skill requests no secrets |
| No return promises / passive-income language | Copy says "bond at risk," never yield/returns |

## Website

- Built separately — not part of this repo's scope.
- We expose: clean read functions, the events above, and a shipped ABI.

## Timeline

- **Week 1 (→ ~Nov 28):** contracts + tests → BSC testnet → mainnet deploy →
  BscScan verification → Agentic Wallet skill.
- **Weeks 2–3 (→ Dec 9):** drive ≥30 real Agent ID holders to interact.
  Outreach, live demos, dogfooding — no sybil activity.

## Deployment status

- [x] Contracts written + unit-tested (mock registry)
- [x] Fork tests pass against live BSC mainnet registry + real Agent ID holders
- [x] **BSC testnet deploy** — done, smoke-tested end to end
  (mint → declare bonded promise → attest → `scoreOf = (1,0,1,10000)`):
  - MockAgentID `0x50dB8293aAbB6058882d3f3410BC76Ff44306a76`
  - PromiseBond `0xBE023BD129711301732Bb94A15F09b71A93ac27C`
  - AgentReputation `0x9A22577ce6C24bb0f8dD1aBB41A789E0411900aa`
  - Sourcify: all three `exact_match`. BscScan: needs web form (paid API) —
    std-JSON inputs + settings + constructor args in `verification/`.
- [ ] Mainnet deploy + BscScan verify — commands in README; **do not run
  until user funds a fresh mainnet deployer and says go.**

## Repo rules

- Repo: **`cipoklean/oathbound`** — pushed to `main`.
- All commits authored **and** committed as:
  - `user.name`: `cipoklean`
  - `user.email`: `82593998+cipoklean@users.noreply.github.com`
- **No co-author trailers, no bot identities, no "Generated with" footers.**
  (Overrides default Devin commit format for this repo.)
