import { useMemo, useState } from 'react'
import { useAccount } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { Plus } from 'lucide-react'
import { Link } from '@/lib/router'
import { STATUS, sameAddress } from '@/lib/escrow'
import { usdc } from '@/lib/format'
import { useEscrows } from '@/hooks/useEscrows'
import { EscrowCard } from '@/components/EscrowCard'
import { EmptyState, PageTitle, Skeleton } from '@/components/ui'

type Filter = 'all' | 'client' | 'freelancer'

const FILTERS: { id: Filter; label: string }[] = [
  { id: 'all', label: 'All mine' },
  { id: 'client', label: 'As client' },
  { id: 'freelancer', label: 'As freelancer' },
]

export function Dashboard() {
  const { address, isConnected } = useAccount()
  const { escrows, isLoading, isError } = useEscrows()
  const [filter, setFilter] = useState<Filter>('all')

  const mine = useMemo(
    () =>
      escrows.filter((e) => {
        const isClient = sameAddress(address, e.client)
        const isFreelancer = sameAddress(address, e.freelancer)
        if (filter === 'client') return isClient
        if (filter === 'freelancer') return isFreelancer
        return isClient || isFreelancer
      }),
    [escrows, address, filter],
  )

  const locked = useMemo(
    () => escrows.filter((e) => e.status === STATUS.Funded && (sameAddress(address, e.client) || sameAddress(address, e.freelancer))),
    [escrows, address],
  )
  const lockedTotal = locked.reduce((sum, e) => sum + e.amount, 0n)

  return (
    <div>
      <PageTitle
        title="Dashboard"
        subtitle="Your escrow agreements, read live from the contract."
        action={
          <Link to="/create" className="btn-primary">
            <Plus className="size-4" aria-hidden /> New escrow
          </Link>
        }
      />

      {!isConnected ? (
        <EmptyState
          title="Connect your wallet"
          body="Connect to see the escrows where you are the client or the freelancer."
          action={
            <ConnectKitButton.Custom>
              {({ show }) => (
                <button type="button" className="btn-primary" onClick={show}>
                  Connect wallet
                </button>
              )}
            </ConnectKitButton.Custom>
          }
        />
      ) : (
        <>
          <section className="card mb-5 flex flex-wrap items-end justify-between gap-4 p-5" aria-label="Summary">
            <div>
              <p className="label !mb-1">Currently held in escrow for you</p>
              <p className="flex items-baseline gap-1.5">
                <span className="tabular font-display text-4xl font-bold text-ink">{usdc(lockedTotal)}</span>
                <span className="text-sm font-medium text-subtle">USDC</span>
              </p>
            </div>
            <p className="text-sm text-muted">
              {locked.length} funded {locked.length === 1 ? 'escrow' : 'escrows'}
            </p>
          </section>

          <div className="mb-5 flex flex-wrap gap-2" role="tablist" aria-label="Filter by role">
            {FILTERS.map((f) => (
              <button
                key={f.id}
                type="button"
                role="tab"
                aria-selected={filter === f.id}
                onClick={() => setFilter(f.id)}
                className={`min-h-11 rounded-full px-4 text-sm font-semibold transition ${
                  filter === f.id ? 'bg-navy text-white' : 'border border-line bg-white text-muted hover:text-ink'
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>

          {isLoading ? (
            <div className="grid gap-4 sm:grid-cols-2">
              <Skeleton className="h-52" />
              <Skeleton className="h-52" />
            </div>
          ) : isError ? (
            <EmptyState title="Could not load escrows" body="The Arc Testnet RPC did not answer. Try again in a moment." />
          ) : mine.length === 0 ? (
            <EmptyState
              title="No escrows yet"
              body={
                filter === 'all'
                  ? 'Create your first escrow, or ask a client to create one with your wallet address.'
                  : `You are not the ${filter} on any escrow yet.`
              }
              action={
                <Link to="/create" className="btn-primary">
                  Create an escrow
                </Link>
              }
            />
          ) : (
            <div className="grid gap-4 sm:grid-cols-2">
              {mine.map((e) => (
                <EscrowCard key={e.id.toString()} escrow={e} me={address} />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  )
}
