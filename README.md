# FreelanceSafe

A USDC escrow app for freelancers and clients on Arc Testnet. The client locks test USDC in a smart contract, and it is released to the freelancer only when the client approves the work. Experimental MVP: test tokens only, not audited, not production ready.

Built with [Arc Studio](https://studio.arc.io)

## What you can do

- Connect an EVM wallet and see whether it is on Arc Testnet, with a one-click network switch.
- Create an escrow with a title, description, freelancer address, USDC amount, and optional deadline.
- Approve and deposit test USDC into the escrow.
- Release payment to the freelancer (client only).
- Cancel an unfunded escrow, or refund a funded one under the rules below.
- Browse a dashboard filtered by your role, and a live activity feed with explorer links.

## Escrow rules

- Only the client can fund, cancel an unfunded escrow, or release payment.
- The freelancer can return the funds to the client at any time before release.
- With a deadline, the client can claim a refund only after the deadline passes.
- Without a deadline, the client can claim a refund 180 days after funding.
- Released, refunded, and cancelled escrows are closed. Nothing can be paid twice.
- There is no admin role and no hidden withdrawal.

## Tech stack

React, Vite, TypeScript, Tailwind CSS, wagmi, viem, ConnectKit. Solidity 0.8.28 with OpenZeppelin and Foundry.

## Development

Prerequisites: [Bun](https://bun.sh) and [Foundry](https://getfoundry.sh).

```bash
bun install
bun run dev
```

Environment variables (public values, set in `.env`):

- `VITE_ESCROW_ADDRESS`: deployed escrow contract address on Arc Testnet.
- `VITE_ESCROW_DEPLOY_BLOCK`: block the contract was deployed at, where activity scans start.
- `RPC_PROXY_BASE_URL`, `RPC_PROXY_TOKEN`, `RPC_PROXY_CHAINS`: optional outside Arc Studio. Not read by the frontend.

Build and test:

```bash
bun run contracts:build   # compile contracts
bun run contracts:test    # run the Foundry test suite
bun run check             # lint and typecheck the frontend
```

Routes use clean paths (`/dashboard`, `/escrow/1`). When hosting the built app, configure your host to serve `index.html` for unknown paths.

## Getting test USDC

Use Arc Studio's **Get test USDC** button, or the [Circle faucet](https://faucet.circle.com) and select Arc Testnet. On Arc, USDC is also the gas token, so one balance covers deposits and fees.
