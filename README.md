# Oathbound

*Promise bonds for AI agents.*

An agent declares a promise on-chain. Its counterparty attests that it was
kept — or anyone can expire it after the deadline, burning the bond and
recording a broken promise. Reputation accrues to an address that can never
be sold or transferred, because it is gated on the
[SPACE ID Agent ID](https://web3.binance.com/) registry: an ERC-721 identity,
one per user, non-transferable.

Built for the BNB Chain × Binance Wallet Agent ID Hackathon.

## Contracts

| Contract | Role |
|---|---|
| `src/PromiseBond.sol` | Promise lifecycle: declare → attest / expire. Holds optional BNB stakes. |
| `src/AgentReputation.sol` | Immutable `kept` / `broken` / `bondedKept` counts + `scoreOf(address)`. Writable only by PromiseBond. |

`AgentReputation` is deployed by `PromiseBond`'s constructor; the recorder
link is fixed at deployment forever.

### Lifecycle

```
declarePromise(taskHash, counterparty, deadline)   [payable, stake optional]
        │
        ├─ attest(promiseId)        ← counterparty only, before deadline
        │     → stake back to promiser, records kept (+bondedKept if stake>0)
        │
        └─ expire(promiseId)        ← anyone, strictly after deadline
              → stake burned to 0x…dEaD, records broken
```

No cancellation. A declared promise resolves exactly once.

### Agent ID gate

Both promiser and counterparty must hold an Agent ID:
`balanceOf > 0` on `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
(SPACE ID Agent ID, ERC-721, non-transferable, BNB Chain mainnet).

## Hackathon red-line compliance

| Rule | How Oathbound complies |
|---|---|
| Owner permissions must be documented & minimal | **Zero owner powers.** No owner, no pause, no admin functions, no upgradeability. Contracts are immutable at deploy. |
| No automatic or hidden transfers; no unlimited approvals | Funds move only back to the promiser (`attest`) or to the burn address (`expire`). No third-party transfers, no `approve` flow at all. |
| No QR/pairing-code wallet login; no server sessions acting for users | All actions are normal on-chain transactions signed by the user's own wallet. |
| No "Binance"/"BNB" in project/token/domain names | Project name is **Oathbound**. |
| No looking up another agent's wallet by name | Reputation is keyed by address (`scoreOf(address)`); no handle→address lookup is exposed. |
| No seed phrases, keys, secrets, or pairing codes collected | Contracts take calldata only. The deploy flow uses `cast wallet` keystores, not committed keys. |
| No return promises or passive-income language | Bonds are strictly at-risk collateral. Nothing yields anything. |

## Known limitations

- **Collusion farming.** Two cooperating Agent ID holders can attest each
  other's promises to inflate kept counts at ~zero cost (especially 0-stake
  promises). Accepted for v1 — a kept-promise count is only as meaningful as
  the independence of the counterparty. Mitigation on the roadmap: staked
  dispute panels.
- `scoreBps` weights 0-stake and bonded promises equally; `bondedKept` is
  exposed so consumers can weight bonded history themselves.
- Reputation is per-address. Agent ID is non-transferable and one-per-user,
  so an identity cannot be sold — but a user who somehow controls a second
  Agent ID starts from zero on it.
- If a promiser is a contract that reverts on BNB receive, `attest` fails and
  the stake can only be burned via `expire`. Self-inflicted; documented.

## Development

```bash
forge build          # compile
forge test -vvv      # unit tests (mock registry)

# fork tests against live BSC mainnet + real Agent ID registry
BSC_RPC_URL=https://bsc.publicnode.com forge test --match-path "test/fork/*" -vvv
```

## Deployment

The real Agent ID registry exists on **BSC mainnet only**, so testnet
deploys a `MockAgentID` (open `mint`) as the gate stand-in.

```bash
# testnet (chain 97): deploys MockAgentID + PromiseBond + AgentReputation
forge script script/DeployTestnet.s.sol --rpc-url bsc_testnet --broadcast \
    --keystore keystore --password-file keystore/password.txt

# mainnet (chain 56): gates on the real registry
forge script script/Deploy.s.sol --rpc-url bsc --broadcast \
    --keystore keystore --password-file keystore/password.txt \
    --verify --etherscan-api-key $BSCSCAN_API_KEY
```

`PromiseBond` deploys `AgentReputation` internally; verify both addresses
(the script logs both). Constructor arg for PromiseBond is the registry
address `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`.

## For the website

- Events: `PromiseDeclared`, `PromiseAttested`, `PromiseExpired` (promiseId
  indexed on all; promiser/counterparty indexed where useful).
- Reads: `promises(id)`, `getPromise(id)`, `promiseCount()`,
  `reputation().scoreOf(address)` → `(kept, broken, bondedKept, scoreBps)`.
- Prebuilt ABIs live in `abi/` — regenerate with:
  `forge inspect PromiseBond abi > abi/PromiseBond.abi.json` (same for
  `AgentReputation`).

## Roadmap (post-hackathon)

- Staked dispute/arbitration panels (collusion resistance)
- Mutual-stake gig escrow
- Reputation-weighted agent credit
- Liveness heartbeats / agent-mandate succession

## Repo hygiene

- Contracts: `src/` · tests: `test/` (+ `test/fork/`) · deploy: `script/`
- `lib/forge-std` is a git submodule: `git clone --recurse-submodules` or
  `git submodule update --init` after cloning.
