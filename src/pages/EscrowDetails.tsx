import { ArrowLeft } from 'lucide-react'
import { Link } from '@/lib/router'
import { NO_DEADLINE_REFUND_DELAY } from '@/lib/escrow'
import { formatDateTime, formatDeadline, usdc } from '@/lib/format'
import { useEscrow } from '@/hooks/useEscrows'
import { useActivity } from '@/hooks/useActivity'
import { ActivityRow } from '@/components/ActivityRow'
import { EscrowActions } from '@/components/EscrowActions'
import { AddressLink, EmptyState, Skeleton, StatusBadge } from '@/components/ui'

export function EscrowDetails({ id }: { id: bigint }) {
  const { escrow, isLoading, isError } = useEscrow(id)
  const activity = useActivity()

  if (isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-10 w-2/3" />
        <Skeleton className="h-64" />
      </div>
    )
  }

  if (isError || !escrow) {
    return (
      <EmptyState
        title="Escrow not found"
        body={`There is no escrow with ID ${id.toString()} on this contract.`}
        action={
          <Link to="/dashboard" className="btn-primary">
            Back to dashboard
          </Link>
        }
      />
    )
  }

  const history = (activity.data?.items ?? []).filter((i) => i.escrowId === id)
  const days = Number(NO_DEADLINE_REFUND_DELAY / 86_400n)

  return (
    <div>
      <Link to="/dashboard" className="mb-4 inline-flex min-h-11 items-center gap-1.5 text-sm font-semibold text-muted hover:text-ink">
        <ArrowLeft className="size-4" aria-hidden /> Dashboard
      </Link>

      <div className="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <div className="space-y-6">
          <section className="card p-6">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="font-mono text-xs text-subtle">Escrow #{escrow.id.toString()}</p>
                <h1 className="mt-1 break-words text-3xl font-bold text-ink">{escrow.title}</h1>
              </div>
              <StatusBadge status={escrow.status} />
            </div>

            <p className="mt-5 flex items-baseline gap-1.5">
              <span className="tabular font-display text-5xl font-bold text-ink">{usdc(escrow.amount)}</span>
              <span className="text-base font-medium text-subtle">USDC</span>
            </p>

            {escrow.description && (
              <p className="mt-5 whitespace-pre-wrap break-words rounded-2xl bg-canvas p-4 text-sm text-muted">
                {escrow.description}
              </p>
            )}

            <dl className="mt-5 grid gap-x-6 gap-y-4 text-sm sm:grid-cols-2">
              <div>
                <dt className="label !mb-1">Client</dt>
                <dd>
                  <AddressLink address={escrow.client} />
                </dd>
              </div>
              <div>
                <dt className="label !mb-1">Freelancer</dt>
                <dd>
                  <AddressLink address={escrow.freelancer} />
                </dd>
              </div>
              <div>
                <dt className="label !mb-1">Created</dt>
                <dd className="text-ink">{formatDateTime(escrow.createdAt)}</dd>
              </div>
              <div>
                <dt className="label !mb-1">Deadline</dt>
                <dd className="text-ink">{formatDeadline(escrow.deadline)}</dd>
              </div>
            </dl>
          </section>

          <section className="card p-6" aria-labelledby="rules">
            <h2 id="rules" className="text-lg font-semibold text-ink">
              Payment and refund conditions
            </h2>
            <ul className="mt-3 list-disc space-y-1.5 pl-5 text-sm text-muted">
              <li>Only the client can release the payment to the freelancer.</li>
              <li>The client can cancel only while the escrow is unfunded.</li>
              <li>The freelancer can return the funds to the client at any time before release.</li>
              <li>
                {escrow.deadline !== 0n
                  ? `The client can claim a refund only after ${formatDateTime(escrow.deadline)}.`
                  : `There is no deadline, so the client can claim a refund ${days} days after funding.`}
              </li>
              <li>After release, refund, or cancellation, the escrow is closed for good.</li>
            </ul>
          </section>

          <section className="card p-6" aria-labelledby="history">
            <h2 id="history" className="text-lg font-semibold text-ink">
              History
            </h2>
            {activity.isLoading ? (
              <Skeleton className="mt-3 h-16" />
            ) : history.length === 0 ? (
              <p className="mt-2 text-sm text-muted">No onchain events found yet.</p>
            ) : (
              <ul className="mt-1 divide-y divide-line">
                {history.map((item) => (
                  <ActivityRow key={item.key} item={item} showEscrowLink={false} />
                ))}
              </ul>
            )}
          </section>
        </div>

        <aside className="lg:sticky lg:top-28 lg:self-start">
          <div className="card p-6">
            <h2 className="mb-4 text-lg font-semibold text-ink">Actions</h2>
            <EscrowActions escrow={escrow} />
          </div>
        </aside>
      </div>
    </div>
  )
}
