import { ArrowDownToLine, Ban, FilePlus2, RotateCcw, SendHorizontal } from 'lucide-react'
import type { ActivityItem, ActivityKind } from '@/hooks/useActivity'
import { Link } from '@/lib/router'
import { formatDateTime, usdc } from '@/lib/format'
import { TxLink } from '@/components/ui'

const META: Record<ActivityKind, { label: string; icon: typeof FilePlus2; tone: string }> = {
  created: { label: 'Escrow created', icon: FilePlus2, tone: 'bg-slate-100 text-slate-700' },
  funded: { label: 'USDC deposited', icon: ArrowDownToLine, tone: 'bg-brand-soft text-brand-dark' },
  released: { label: 'Payment released', icon: SendHorizontal, tone: 'bg-emerald-50 text-ok' },
  refunded: { label: 'Refunded to client', icon: RotateCcw, tone: 'bg-amber-50 text-warn' },
  cancelled: { label: 'Escrow cancelled', icon: Ban, tone: 'bg-slate-100 text-slate-500' },
}

export function ActivityRow({ item, showEscrowLink = true }: { item: ActivityItem; showEscrowLink?: boolean }) {
  const meta = META[item.kind]
  return (
    <li className="flex items-start gap-3 py-3.5">
      <span className={`flex size-9 shrink-0 items-center justify-center rounded-xl ${meta.tone}`}>
        <meta.icon className="size-4" aria-hidden />
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-baseline justify-between gap-x-3">
          <p className="text-sm font-semibold text-ink">
            {meta.label}
            {item.amount !== undefined && <span className="tabular font-medium text-muted"> · {usdc(item.amount)} USDC</span>}
          </p>
          <p className="text-xs text-subtle">{item.timestamp ? formatDateTime(item.timestamp) : `Block ${item.blockNumber}`}</p>
        </div>
        <div className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs">
          {showEscrowLink && (
            <Link to={`/escrow/${item.escrowId}`} className="font-semibold text-brand-dark hover:underline">
              Escrow #{item.escrowId.toString()}
            </Link>
          )}
          <TxLink hash={item.txHash} />
        </div>
      </div>
    </li>
  )
}
