# Verification

BscScan's API (Etherscan V2) lists BSC chains 56/97 as paid-tier only, so the
guaranteed free path is BscScan's **Verify & Publish** web form using the
standard-JSON inputs in this directory.

## Deployed addresses

### BSC testnet (chain 97)

| Contract | Address | BscScan | Sourcify |
|---|---|---|---|
| PromiseBond | `0xBE023BD129711301732Bb94A15F09b71A93ac27C` | web form needed | exact_match |
| AgentReputation | `0x9A22577ce6C24bb0f8dD1aBB41A789E0411900aa` | web form needed | exact_match |
| MockAgentID (gate stand-in) | `0x50dB8293aAbB6058882d3f3410BC76Ff44306a76` | web form needed | exact_match |

Deployer (throwaway): `0xb999CFcD4CE07976Eb8B4e2f29045A60dcCB44D7`

### BSC mainnet (chain 56)

_Not deployed yet — see PLAN.md gate._

## Compiler settings (for the BscScan form)

- Compiler: **v0.8.30**
- Optimization: **Yes, 200 runs**
- EVM version: **shanghai**
- License: **MIT**
- Contract file to verify: the matching `.standard-json.json` in this dir.

## Constructor arguments (ABI-encoded)

| Contract | Args |
|---|---|
| PromiseBond **testnet** | `00000000000000000000000050db8293aabb6058882d3f3410bc76ff44306a76` (MockAgentID address) |
| PromiseBond **mainnet** | `00000000000000000000000060b9262456de011f7d15a54cdd8c48baaa8b022f` (real Agent ID registry) |
| AgentReputation | none |
| MockAgentID | none |

## Routes

1. **BscScan web form (required by the hackathon).**
   Contract page → Contract tab → Verify & Publish → "via Standard JSON
   Input". Upload the matching file, enter the settings above and the
   constructor args if asked.
2. **Sourcify (already done for testnet).**
   `forge verify-contract <addr> <path>:<Name> --chain-id <56|97> --verifier sourcify`
   Free, no key. Note: BscScan does **not** import Sourcify results — this is
   a bonus (Sourcify repo + explorers that consume it), not a substitute.
3. **BscScan API (only if a paid key exists).**
   `forge verify-contract <addr> <path>:<Name> --chain-id <56|97> --verify --etherscan-api-key <key>`

Regenerate inputs anytime:
`forge verify-contract <addr> <path>:<Name> --show-standard-json-input > verification/<Name>.standard-json.json`
