import { erc20Abi, type Address } from 'viem'
import { useReadContract } from 'wagmi'
import { CHAIN_ID, ESCROW_ADDRESS, USDC_ADDRESS } from '@/lib/escrow'

/** USDC balance in the 6-decimal ERC-20 view (the same pool as native gas on Arc). */
export function useUsdcBalance(owner?: Address) {
  return useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: owner ? [owner] : undefined,
    chainId: CHAIN_ID,
    query: { enabled: !!owner, refetchInterval: 10_000 },
  })
}

/** How much USDC the connected wallet has approved the escrow contract to spend. */
export function useEscrowAllowance(owner?: Address) {
  return useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'allowance',
    args: owner ? [owner, ESCROW_ADDRESS] : undefined,
    chainId: CHAIN_ID,
    query: { enabled: !!owner, refetchInterval: 10_000 },
  })
}
