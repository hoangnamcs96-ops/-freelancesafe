import { BaseError, ContractFunctionRevertedError, UserRejectedRequestError } from 'viem'
import { formatUnitsFixed } from '@/onchain-money'
import { USDC_DECIMALS } from '@/lib/escrow'

export function shortAddress(addr?: string): string {
  if (!addr) return ''
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`
}

export function shortHash(hash?: string): string {
  if (!hash) return ''
  return `${hash.slice(0, 10)}...${hash.slice(-6)}`
}

/** Formats a raw 6-decimal USDC amount (ERC-20 view) for display. */
export function usdc(raw: bigint, digits = 2): string {
  const fixed = formatUnitsFixed(raw, USDC_DECIMALS, digits)
  const [whole, frac] = fixed.split('.')
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  return frac ? `${grouped}.${frac}` : grouped
}

export function formatDateTime(seconds: bigint | number): string {
  const ms = Number(seconds) * 1000
  return new Date(ms).toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatDeadline(deadline: bigint): string {
  return deadline === 0n ? 'No deadline' : formatDateTime(deadline)
}

const REVERT_MESSAGES: Record<string, string> = {
  NotClient: 'Only the client of this escrow can do that.',
  NotFreelancer: 'Only the freelancer of this escrow can do that.',
  InvalidStatus: 'This escrow is not in a state that allows that action.',
  DeadlineNotExpired: 'The refund window has not opened yet.',
  EscrowNotFound: 'That escrow does not exist.',
  InvalidFreelancer: 'That freelancer address cannot be used.',
  ZeroAddress: 'The freelancer address cannot be empty.',
  InvalidAmount: 'The payment amount must be greater than zero.',
  InvalidDeadline: 'The deadline must be in the future.',
  InvalidTitleLength: 'The title must be between 1 and 100 bytes.',
  InvalidDescriptionLength: 'The description is too long.',
  UnexpectedTransferAmount: 'The token did not deliver the exact amount.',
  ERC20InsufficientAllowance: 'Allowance is too low. Approve USDC first.',
  ERC20InsufficientBalance: 'Your USDC balance is too low for this deposit.',
}

export interface DescribedError {
  rejected: boolean
  message: string
}

export function describeError(error: unknown): DescribedError {
  if (error instanceof BaseError) {
    if (error.walk((e) => e instanceof UserRejectedRequestError)) {
      return { rejected: true, message: 'Transaction cancelled.' }
    }
    const reverted = error.walk((e) => e instanceof ContractFunctionRevertedError)
    if (reverted instanceof ContractFunctionRevertedError) {
      const name = reverted.data?.errorName
      if (name && REVERT_MESSAGES[name]) return { rejected: false, message: REVERT_MESSAGES[name] }
    }
    const lower = error.message.toLowerCase()
    if (lower.includes('user rejected') || lower.includes('user denied')) {
      return { rejected: true, message: 'Transaction cancelled.' }
    }
    if (lower.includes('insufficient funds') || lower.includes('exceeds the balance')) {
      return { rejected: false, message: 'Not enough USDC to cover the transaction fee.' }
    }
    return { rejected: false, message: error.shortMessage || 'Transaction failed. Please try again.' }
  }
  if (error instanceof Error && error.message.toLowerCase().includes('user rejected')) {
    return { rejected: true, message: 'Transaction cancelled.' }
  }
  return { rejected: false, message: 'Something went wrong. Please try again.' }
}

export function utf8Length(value: string): number {
  return new TextEncoder().encode(value).length
}
