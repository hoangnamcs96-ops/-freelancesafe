# FreelanceSafe

> Built with Arc Studio. Project memory for future agents and humans.

## What This App Does

USDC escrow for freelancers on Arc Testnet. Client creates a job, funds it with test USDC, and releases to the freelancer. Refund rules are enforced by `contracts/FreelanceEscrow.sol` (no owner, no admin).

## Tech Stack

- Frontend: React 18, Vite, TypeScript, Tailwind (navy and blue theme), wagmi v2, viem, ConnectKit. Path routing in `src/lib/router.tsx` (no router library).
- Contracts: Solidity 0.8.28, OpenZeppelin 5.6.1, Foundry. `bun run contracts:build`, `bun run contracts:test`.
- Chain: Arc Testnet (5042002). Token: official Arc USDC `0x3600000000000000000000000000000000000000` (6 decimals ERC-20 view of the native gas token).

## Deployments

- FreelanceEscrow (Arc Testnet): `0xebfcc213723feaf64fe42f92d0b1a239c7bd442e`
  - Deploy tx: `0x5d3e05ea0debd92c1756ebcc0e5379dadba7b692a885725020fa8215d2d0e4b1`, block 69276538
  - Constructor arg: token = Arc USDC above
  - Configured in `.env` as `VITE_ESCROW_ADDRESS` and `VITE_ESCROW_DEPLOY_BLOCK`. The ABI is in `src/lib/escrowAbi.ts` (regenerate from `contracts/out` if the contract changes).

## Contract rules (keep in sync with the UI copy)

- `createEscrow` (client), `fund` / `cancel` (client, Created only), `release` (client, Funded only).
- `refundByFreelancer`: freelancer, any time while Funded.
- `claimExpiredRefund`: client, strictly after `deadline`, or strictly after `fundedAt + 180 days` when no deadline.
- Freelancer address is rejected if zero, the client, the token, the escrow, the Arc system emitter, or <= 0xFFFF.
- Arc enforces the USDC blocklist at runtime: a blocklisted freelancer cannot receive a release.

## Decisions

- Tests: `contracts/test/FreelanceEscrow*.t.sol` with mocks in `contracts/test-helpers/`.
- Activity reads contract events from the deploy block (`useActivity`), never from block 0.
- Not audited. Do not describe it as production ready.

## Key Files

- `src/App.tsx` routes; `src/pages/*` the five pages; `src/components/EscrowActions.tsx` role-based actions.
- `src/hooks/useTx.ts` single wallet-transaction runner (switches chain, waits for a successful receipt).

## Hosting

- Netlify: https://shiny-strudel-115986.netlify.app (built with `bunx vite build`, deployed from `dist`; `public/_redirects` provides the SPA fallback). Redeploy after any change to `.env` VITE_ values, since they are baked in at build time.
