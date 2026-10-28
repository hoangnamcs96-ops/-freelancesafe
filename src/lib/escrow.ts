import { isAddress, zeroAddress, type Address } from 'viem'
import { arcTestnet } from 'viem/chains'
import { getUsdc, requireChain } from '@/onchain-facts'

export const CHAIN_ID = arcTestnet.id
export const CHAIN = requireChain(CHAIN_ID)

const rawAddress = import.meta.env.VITE_ESCROW_ADDRESS as string | undefined
const rawBlock = import.meta.env.VITE_ESCROW_DEPLOY_BLOCK as string | undefined

/** True when the deployed escrow contract address is configured in .env. */
export const ESCROW_CONFIGURED = typeof rawAddress === 'string' && isAddress(rawAddress)
export const ESCROW_ADDRESS: Address = ESCROW_CONFIGURED ? (rawAddress as Address) : zeroAddress

/** Block the contract was deployed at. Event scans start here, never at block 0. */
export const DEPLOY_BLOCK: bigint | undefined =
  typeof rawBlock === 'string' && /^\d+$/.test(rawBlock) ? BigInt(rawBlock) : undefined

const usdc = getUsdc(CHAIN_ID)
if (!usdc) throw new Error('USDC is not registered for Arc Testnet')
export const USDC_ADDRESS: Address = usdc.address as Address
export const USDC_DECIMALS = usdc.decimals

/** Mirrors FreelanceEscrow.NO_DEADLINE_REFUND_DELAY (180 days, in seconds). */
export const NO_DEADLINE_REFUND_DELAY = 15_552_000n

export const STATUS = {
  None: 0,
  Created: 1,
  Funded: 2,
  Released: 3,
  Refunded: 4,
  Cancelled: 5,
} as const

export type StatusName = 'Created' | 'Funded' | 'Released' | 'Refunded' | 'Cancelled'

export const STATUS_LABEL: Record<number, StatusName | 'Unknown'> = {
  1: 'Created',
  2: 'Funded',
  3: 'Released',
  4: 'Refunded',
  5: 'Cancelled',
}

export interface Escrow {
  id: bigint
  client: Address
  freelancer: Address
  amount: bigint
  createdAt: bigint
  deadline: bigint
  fundedAt: bigint
  status: number
  title: string
  description: string
}

interface RawEscrow {
  client: Address
  freelancer: Address
  amount: bigint
  createdAt: bigint
  deadline: bigint
  fundedAt: bigint
  status: number
  title: string
  description: string
}

export function toEscrow(id: bigint, raw: RawEscrow): Escrow {
  return {
    id,
    client: raw.client,
    freelancer: raw.freelancer,
    amount: BigInt(raw.amount),
    createdAt: BigInt(raw.createdAt),
    deadline: BigInt(raw.deadline),
    fundedAt: BigInt(raw.fundedAt),
    status: Number(raw.status),
    title: raw.title,
    description: raw.description,
  }
}

/** Timestamp (seconds) strictly after which the client may claim a refund. */
export function refundAfter(e: Escrow): bigint {
  return e.deadline !== 0n ? e.deadline : e.fundedAt + NO_DEADLINE_REFUND_DELAY
}

export function sameAddress(a?: string, b?: string): boolean {
  return !!a && !!b && a.toLowerCase() === b.toLowerCase()
}
