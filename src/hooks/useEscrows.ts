import { useMemo } from 'react'
import { useReadContract } from 'wagmi'
import { escrowAbi } from '@/lib/escrowAbi'
import { CHAIN_ID, ESCROW_ADDRESS, toEscrow, type Escrow } from '@/lib/escrow'

const PAGE = 100n
const REFRESH_MS = 10_000

/** Reads the newest escrows straight from the contract (up to 100). */
export function useEscrows() {
  const count = useReadContract({
    address: ESCROW_ADDRESS,
    abi: escrowAbi,
    functionName: 'escrowCount',
    chainId: CHAIN_ID,
    query: { refetchInterval: REFRESH_MS },
  })

  const total = count.data
  const start = total !== undefined && total > PAGE ? total - PAGE + 1n : 1n

  const list = useReadContract({
    address: ESCROW_ADDRESS,
    abi: escrowAbi,
    functionName: 'getEscrows',
    args: [start, PAGE],
    chainId: CHAIN_ID,
    query: { enabled: total !== undefined && total > 0n, refetchInterval: REFRESH_MS },
  })

  const escrows = useMemo<Escrow[]>(() => {
    if (!list.data) return []
    return list.data.map((raw, i) => toEscrow(start + BigInt(i), raw)).reverse()
  }, [list.data, start])

  return {
    escrows,
    total,
    isLoading: count.isLoading || (total !== undefined && total > 0n && list.isLoading),
    isError: count.isError || list.isError,
    refetch: async () => {
      await count.refetch()
      await list.refetch()
    },
  }
}

/** Reads a single escrow by id. */
export function useEscrow(id: bigint) {
  const query = useReadContract({
    address: ESCROW_ADDRESS,
    abi: escrowAbi,
    functionName: 'getEscrow',
    args: [id],
    chainId: CHAIN_ID,
    query: { refetchInterval: REFRESH_MS, retry: 1 },
  })
  const escrow = useMemo<Escrow | undefined>(
    () => (query.data ? toEscrow(id, query.data) : undefined),
    [query.data, id],
  )
  return { escrow, isLoading: query.isLoading, isError: query.isError }
}
