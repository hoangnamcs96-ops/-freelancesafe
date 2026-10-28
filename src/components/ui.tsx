import type { ReactNode } from 'react'
import { AlertCircle, CheckCircle2, ExternalLink, Loader2 } from 'lucide-react'
import { buildAddressExplorerUrl, buildTxExplorerUrl } from '@/onchain-facts'
import { CHAIN_ID, STATUS_LABEL } from '@/lib/escrow'
import { shortAddress, shortHash } from '@/lib/format'
import type { TxState } from '@/hooks/useTx'

const STATUS_STYLE: Record<string, string> = {
  Created: 'bg-slate-100 text-slate-700 ring-slate-200',
  Funded: 'bg-brand-soft text-brand-dark ring-brand/20',
  Released: 'bg-emerald-50 text-ok ring-emerald-200',
  Refunded: 'bg-amber-50 text-warn ring-amber-200',
  Cancelled: 'bg-slate-100 text-slate-500 ring-slate-200',
}

export function StatusBadge({ status }: { status: number }) {
  const label = STATUS_LABEL[status] ?? 'Unknown'
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset ${
        STATUS_STYLE[label] ?? STATUS_STYLE.Created
      }`}
    >
      {label}
    </span>
  )
}

export function AddressLink({ address, label }: { address: string; label?: string }) {
  return (
    <a
      href={buildAddressExplorerUrl(CHAIN_ID, address)}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1 font-mono text-[13px] text-brand-dark underline-offset-2 hover:underline"
      title={address}
    >
      {label ?? shortAddress(address)}
      <ExternalLink className="size-3" aria-hidden />
    </a>
  )
}

export function TxLink({ hash, label }: { hash: string; label?: string }) {
  return (
    <a
      href={buildTxExplorerUrl(CHAIN_ID, hash)}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1 font-mono text-[13px] text-brand-dark underline-offset-2 hover:underline"
      title={hash}
    >
      {label ?? shortHash(hash)}
      <ExternalLink className="size-3" aria-hidden />
    </a>
  )
}

/** Inline transaction status. Renders only states reported by the wallet and the chain. */
export function TxStatus({ state, successLabel }: { state: TxState; successLabel: string }) {
  if (state.phase === 'idle') return null
  return (
    <div
      role="status"
      aria-live="polite"
      className={`mt-3 rounded-2xl border px-4 py-3 text-sm ${
        state.phase === 'error'
          ? 'border-red-200 bg-red-50 text-bad'
          : state.phase === 'success'
            ? 'border-emerald-200 bg-emerald-50 text-ok'
            : 'border-brand/20 bg-brand-soft text-brand-dark'
      }`}
    >
      <div className="flex items-start gap-2 font-semibold">
        {state.phase === 'wallet' && (
          <>
            <Loader2 className="mt-0.5 size-4 shrink-0 animate-spin" aria-hidden /> Confirm in your wallet...
          </>
        )}
        {state.phase === 'confirming' && (
          <>
            <Loader2 className="mt-0.5 size-4 shrink-0 animate-spin" aria-hidden /> Waiting for confirmation...
          </>
        )}
        {state.phase === 'success' && (
          <>
            <CheckCircle2 className="mt-0.5 size-4 shrink-0" aria-hidden /> {successLabel}
          </>
        )}
        {state.phase === 'error' && (
          <>
            <AlertCircle className="mt-0.5 size-4 shrink-0" aria-hidden /> {state.error}
          </>
        )}
      </div>
      {state.hash && (
        <div className="mt-1.5 flex flex-wrap items-center gap-2 text-xs font-medium">
          <span className="text-muted">Transaction</span>
          <TxLink hash={state.hash} />
        </div>
      )}
    </div>
  )
}

export function PageTitle({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-3xl font-bold text-ink sm:text-4xl">{title}</h1>
        {subtitle && <p className="mt-1.5 max-w-xl text-[15px] text-muted">{subtitle}</p>}
      </div>
      {action}
    </div>
  )
}

export function EmptyState({ title, body, action }: { title: string; body: string; action?: ReactNode }) {
  return (
    <div className="card flex flex-col items-center px-6 py-14 text-center">
      <h3 className="text-lg font-semibold text-ink">{title}</h3>
      <p className="mt-1.5 max-w-sm text-sm text-muted">{body}</p>
      {action && <div className="mt-5">{action}</div>}
    </div>
  )
}

export function Skeleton({ className = '' }: { className?: string }) {
  return <div className={`animate-pulse rounded-xl bg-line/80 ${className}`} aria-hidden />
}
