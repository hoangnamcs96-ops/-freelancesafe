import { useMemo, useState } from 'react'
import { useAccount } from 'wagmi'
import { DEPLOY_BLOCK, sameAddress } from '@/lib/escrow'
import { useActivity } from '@/hooks/useActivity'
import { ActivityRow } from '@/components/ActivityRow'
import { EmptyState, PageTitle, Skeleton } from '@/components/ui'

export function Activity() {
  const { address } = useAccount()
  const { data, isLoading, isError } = useActivity()
  const [scope, setScope] = useState<'mine' | 'all'>('all')

  const items = useMemo(() => {
    const all = data?.items ?? []
    if (scope === 'all' || !address) return all
    return all.filter((i) => i.parties.some((p) => sameAddress(p, address)))
  }, [data, scope, address])

  return (
    <div className="mx-auto max-w-2xl">
      <PageTitle title="Activity" subtitle="Every escrow event, read from the contract's onchain logs." />

      <div className="mb-5 flex gap-2" role="tablist" aria-label="Activity scope">
        {(['all', 'mine'] as const).map((s) => (
          <button
            key={s}
            type="button"
            role="tab"
            aria-selected={scope === s}
            onClick={() => setScope(s)}
            className={`min-h-11 rounded-full px-4 text-sm font-semibold transition ${
              scope === s ? 'bg-navy text-white' : 'border border-line bg-white text-muted hover:text-ink'
            }`}
          >
            {s === 'all' ? 'All activity' : 'My activity'}
          </button>
        ))}
      </div>

      {DEPLOY_BLOCK === undefined ? (
        <EmptyState title="Activity is not configured" body="Set VITE_ESCROW_DEPLOY_BLOCK in .env to the contract deployment block." />
      ) : isLoading ? (
        <div className="space-y-3">
          <Skeleton className="h-16" />
          <Skeleton className="h-16" />
          <Skeleton className="h-16" />
        </div>
      ) : isError ? (
        <EmptyState title="Could not load activity" body="The Arc Testnet RPC did not answer. It will retry automatically." />
      ) : items.length === 0 ? (
        <EmptyState
          title="No activity yet"
          body={scope === 'mine' && !address ? 'Connect your wallet to see your own activity.' : 'Events appear here as soon as an escrow is created.'}
        />
      ) : (
        <>
          <ul className="card divide-y divide-line px-5">
            {items.map((item) => (
              <ActivityRow key={item.key} item={item} />
            ))}
          </ul>
          {data && (
            <p className="tabular mt-3 text-center text-xs text-subtle">
              Scanned blocks {data.fromBlock.toString()} to {data.headBlock.toString()} (contract deployment to latest).
            </p>
          )}
        </>
      )}
    </div>
  )
}
