import { useCallback, useState } from 'react'
import { useAccount, usePublicClient, useSwitchChain, useWriteContract } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'
import type { Hash, TransactionReceipt } from 'viem'
import { CHAIN_ID } from '@/lib/escrow'
import { describeError } from '@/lib/format'

export type TxPhase = 'idle' | 'wallet' | 'confirming' | 'success' | 'error'

export interface TxState {
  phase: TxPhase
  hash?: Hash
  error?: string
}

type WriteAsync = ReturnType<typeof useWriteContract>['writeContractAsync']

/**
 * Runs one wallet transaction and reports only states that are verified:
 * wallet prompt, submitted, confirmed (receipt status success) or failed.
 */
export function useTx() {
  const { chainId } = useAccount()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const publicClient = usePublicClient({ chainId: CHAIN_ID })
  const queryClient = useQueryClient()
  const [state, setState] = useState<TxState>({ phase: 'idle' })

  const run = useCallback(
    async (send: (write: WriteAsync) => Promise<Hash>): Promise<TransactionReceipt | null> => {
      if (!publicClient) {
        setState({ phase: 'error', error: 'Arc Testnet RPC is unavailable.' })
        return null
      }
      setState({ phase: 'wallet' })
      try {
        if (chainId !== CHAIN_ID) await switchChainAsync({ chainId: CHAIN_ID })
        const hash = await send(writeContractAsync)
        setState({ phase: 'confirming', hash })
        const receipt = await publicClient.waitForTransactionReceipt({ hash })
        if (receipt.status !== 'success') {
          setState({
            phase: 'error',
            hash,
            error: 'The transaction reverted onchain. Nothing was changed.',
          })
          return null
        }
        setState({ phase: 'success', hash })
        await queryClient.invalidateQueries()
        return receipt
      } catch (error) {
        const described = describeError(error)
        setState(described.rejected ? { phase: 'idle' } : { phase: 'error', error: described.message })
        return null
      }
    },
    [chainId, publicClient, queryClient, switchChainAsync, writeContractAsync],
  )

  const reset = useCallback(() => setState({ phase: 'idle' }), [])

  return { state, run, reset, busy: state.phase === 'wallet' || state.phase === 'confirming' }
}
