import { useQuery } from '@tanstack/react-query'
import { usePublicClient } from 'wagmi'
import type { Address, Hash, PublicClient } from 'viem'
import { escrowAbi } from '@/lib/escrowAbi'
import { CHAIN_ID, DEPLOY_BLOCK, ESCROW_ADDRESS } from '@/lib/escrow'

export type ActivityKind = 'created' | 'funded' | 'released' | 'refunded' | 'cancelled'

export interface ActivityItem {
  key: string
  kind: ActivityKind
  escrowId: bigint
  amount?: bigint
  /** Wallets involved, used for the "mine" filter. */
  parties: Address[]
  txHash: Hash
  blockNumber: bigint
  logIndex: number
  timestamp?: number
}

export interface ActivityResult {
  items: ActivityItem[]
  fromBlock: bigint
  headBlock: bigint
}

type EscrowLog = Awaited<ReturnType<PublicClient['getContractEvents']>>[number]

/** Fetches logs for a block range, halving the range whenever the RPC refuses it. */
async function getLogsAdaptive(client: PublicClient, from: bigint, to: bigint, depth = 0): Promise<EscrowLog[]> {
  try {
    return await client.getContractEvents({
      address: ESCROW_ADDRESS,
      abi: escrowAbi,
      fromBlock: from,
      toBlock: to,
    })
  } catch (error) {
    if (depth >= 14 || from >= to) throw error
    const mid = from + (to - from) / 2n
    const left = await getLogsAdaptive(client, from, mid, depth + 1)
    const right = await getLogsAdaptive(client, mid + 1n, to, depth + 1)
    return [...left, ...right]
  }
}

interface DecodedArgs {
  client?: Address
  freelancer?: Address
  amount?: bigint
  refundedBy?: Address
  id?: bigint
}

function toItem(log: EscrowLog): ActivityItem | null {
  const name = (log as { eventName?: string }).eventName
  const args = (log as { args?: DecodedArgs }).args
  if (!name || !args || args.id === undefined || log.blockNumber === null || log.transactionHash === null) return null
  const kindByName: Record<string, ActivityKind> = {
    EscrowCreated: 'created',
    EscrowFunded: 'funded',
    PaymentReleased: 'released',
    EscrowRefunded: 'refunded',
    EscrowCancelled: 'cancelled',
  }
  const kind = kindByName[name]
  if (!kind) return null
  const parties = [args.client, args.freelancer, args.refundedBy].filter((a): a is Address => !!a)
  return {
    key: `${log.transactionHash}-${log.logIndex}`,
    kind,
    escrowId: args.id,
    amount: args.amount,
    parties,
    txHash: log.transactionHash,
    blockNumber: log.blockNumber,
    logIndex: log.logIndex ?? 0,
  }
}

/**
 * Reads escrow events from the contract, starting at its deployment block.
 * Returns the scanned range so the UI can show real indexing progress.
 */
export function useActivity() {
  const client = usePublicClient({ chainId: CHAIN_ID })

  return useQuery<ActivityResult>({
    queryKey: ['activity', ESCROW_ADDRESS],
    enabled: !!client && DEPLOY_BLOCK !== undefined,
    refetchInterval: 15_000,
    queryFn: async () => {
      if (!client || DEPLOY_BLOCK === undefined) throw new Error('Activity is not configured')
      const head = await client.getBlockNumber()
      const logs = await getLogsAdaptive(client, DEPLOY_BLOCK, head)
      const items = logs.map(toItem).filter((i): i is ActivityItem => i !== null)
      items.sort((a, b) =>
        a.blockNumber === b.blockNumber ? b.logIndex - a.logIndex : a.blockNumber > b.blockNumber ? -1 : 1,
      )
      const recent = items.slice(0, 200)
      const blocks = [...new Set(recent.map((i) => i.blockNumber))]
      const stamps = new Map<bigint, number>()
      await Promise.all(
        blocks.map(async (blockNumber) => {
          const block = await client.getBlock({ blockNumber })
          stamps.set(blockNumber, Number(block.timestamp))
        }),
      )
      return {
        items: recent.map((i) => ({ ...i, timestamp: stamps.get(i.blockNumber) })),
        fromBlock: DEPLOY_BLOCK,
        headBlock: head,
      }
    },
  })
}
