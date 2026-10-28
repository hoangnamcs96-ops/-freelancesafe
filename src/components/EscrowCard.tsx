import { Link } from '@/lib/router'
import { sameAddress, type Escrow } from '@/lib/escrow'
import { formatDateTime, formatDeadline, shortAddress, usdc } from '@/lib/format'
import { StatusBadge } from '@/components/ui'

export function EscrowCard({ escrow, me }: { escrow: Escrow; me?: string }) {
  const role = sameAddress(me, escrow.client) ? 'You are the client' : sameAddress(me, escrow.freelancer) ? 'You are the freelancer' : null
  return (
    <Link
      to={`/escrow/${escrow.id}`}
      className="card block p-5 transition hover:-translate-y-0.5 hover:border-brand/40 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand/25"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="font-mono text-xs text-subtle">Escrow #{escrow.id.toString()}</p>
          <h3 className="mt-0.5 truncate text-lg font-semibold text-ink">{escrow.title}</h3>
        </div>
        <StatusBadge status={escrow.status} />
      </div>

      <div className="mt-4 flex items-baseline gap-1.5">
        <span className="tabular font-display text-3xl font-bold text-ink">{usdc(escrow.amount)}</span>
        <span className="text-sm font-medium text-subtle">USDC</span>
      </div>

      <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 text-xs">
        <div>
          <dt className="text-subtle">Client</dt>
          <dd className="font-mono text-ink">{shortAddress(escrow.client)}</dd>
        </div>
        <div>
          <dt className="text-subtle">Freelancer</dt>
          <dd className="font-mono text-ink">{shortAddress(escrow.freelancer)}</dd>
        </div>
        <div>
          <dt className="text-subtle">Created</dt>
          <dd className="text-ink">{formatDateTime(escrow.createdAt)}</dd>
        </div>
        <div>
          <dt className="text-subtle">Deadline</dt>
          <dd className="text-ink">{formatDeadline(escrow.deadline)}</dd>
        </div>
      </dl>

      {role && <p className="mt-4 text-xs font-semibold text-brand-dark">{role}</p>}
    </Link>
  )
}
