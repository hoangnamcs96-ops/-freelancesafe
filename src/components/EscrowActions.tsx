import { useState } from 'react'
import { useAccount } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { erc20Abi } from 'viem'
import { Loader2 } from 'lucide-react'
import { escrowAbi } from '@/lib/escrowAbi'
import {
  CHAIN_ID,
  ESCROW_ADDRESS,
  STATUS,
  USDC_ADDRESS,
  refundAfter,
  sameAddress,
  type Escrow,
} from '@/lib/escrow'
import { formatDateTime, usdc } from '@/lib/format'
import { useTx } from '@/hooks/useTx'
import { useNowMs } from '@/hooks/useNow'
import { useEscrowAllowance, useUsdcBalance } from '@/hooks/useUsdc'
import { TxStatus } from '@/components/ui'

function useNowSeconds(): bigint {
  return BigInt(Math.floor(useNowMs() / 1000))
}

function Busy({ label }: { label: string }) {
  return (
    <>
      <Loader2 className="size-4 animate-spin" aria-hidden /> {label}
    </>
  )
}

function ConfirmButton({
  label,
  confirmLabel,
  busy,
  busyLabel,
  disabled,
  tone = 'primary',
  onConfirm,
}: {
  label: string
  confirmLabel: string
  busy: boolean
  busyLabel: string
  disabled?: boolean
  tone?: 'primary' | 'ghost'
  onConfirm: () => void
}) {
  const [armed, setArmed] = useState(false)
  const cls = tone === 'primary' ? 'btn-primary' : 'btn-ghost'
  if (busy) {
    return (
      <button type="button" className={`${cls} w-full`} disabled>
        <Busy label={busyLabel} />
      </button>
    )
  }
  if (!armed) {
    return (
      <button type="button" className={`${cls} w-full`} disabled={disabled} onClick={() => setArmed(true)}>
        {label}
      </button>
    )
  }
  return (
    <div className="flex gap-2">
      <button
        type="button"
        className="btn-accent flex-1"
        onClick={() => {
          setArmed(false)
          onConfirm()
        }}
      >
        {confirmLabel}
      </button>
      <button type="button" className="btn-ghost" onClick={() => setArmed(false)}>
        Back
      </button>
    </div>
  )
}

export function EscrowActions({ escrow }: { escrow: Escrow }) {
  const { address, isConnected } = useAccount()
  const now = useNowSeconds()
  const approve = useTx()
  const action = useTx()
  const allowance = useEscrowAllowance(address)
  const balance = useUsdcBalance(address)

  const isClient = sameAddress(address, escrow.client)
  const isFreelancer = sameAddress(address, escrow.freelancer)

  if (escrow.status === STATUS.Released || escrow.status === STATUS.Refunded || escrow.status === STATUS.Cancelled) {
    return (
      <p className="rounded-2xl bg-canvas p-4 text-sm text-muted">
        This escrow is closed. No further actions are possible, and the funds cannot be moved again.
      </p>
    )
  }

  if (!isConnected) {
    return (
      <ConnectKitButton.Custom>
        {({ show }) => (
          <button type="button" className="btn-primary w-full" onClick={show}>
            Connect wallet to take action
          </button>
        )}
      </ConnectKitButton.Custom>
    )
  }

  if (!isClient && !isFreelancer) {
    return (
      <p className="rounded-2xl bg-canvas p-4 text-sm text-muted">
        You are viewing this escrow as an outsider. Only the client and the freelancer can act on it.
      </p>
    )
  }

  const doFund = () =>
    void action.run((write) =>
      write({ address: ESCROW_ADDRESS, abi: escrowAbi, functionName: 'fund', args: [escrow.id], chainId: CHAIN_ID }),
    )
  const doCancel = () =>
    void action.run((write) =>
      write({ address: ESCROW_ADDRESS, abi: escrowAbi, functionName: 'cancel', args: [escrow.id], chainId: CHAIN_ID }),
    )
  const doRelease = () =>
    void action.run((write) =>
      write({ address: ESCROW_ADDRESS, abi: escrowAbi, functionName: 'release', args: [escrow.id], chainId: CHAIN_ID }),
    )
  const doFreelancerRefund = () =>
    void action.run((write) =>
      write({
        address: ESCROW_ADDRESS,
        abi: escrowAbi,
        functionName: 'refundByFreelancer',
        args: [escrow.id],
        chainId: CHAIN_ID,
      }),
    )
  const doClaimRefund = () =>
    void action.run((write) =>
      write({
        address: ESCROW_ADDRESS,
        abi: escrowAbi,
        functionName: 'claimExpiredRefund',
        args: [escrow.id],
        chainId: CHAIN_ID,
      }),
    )
  const doApprove = () =>
    void approve.run((write) =>
      write({
        address: USDC_ADDRESS,
        abi: erc20Abi,
        functionName: 'approve',
        args: [ESCROW_ADDRESS, escrow.amount],
        chainId: CHAIN_ID,
      }),
    )

  // CLIENT, unfunded: approve, deposit, or cancel.
  if (escrow.status === STATUS.Created) {
    if (!isClient) {
      return (
        <p className="rounded-2xl bg-canvas p-4 text-sm text-muted">
          Waiting for the client to deposit {usdc(escrow.amount)} USDC. Start the work once this escrow shows as Funded.
        </p>
      )
    }
    const allowed = allowance.data ?? 0n
    const needsApproval = allowed < escrow.amount
    const short = balance.data !== undefined && balance.data < escrow.amount

    return (
      <div className="space-y-4">
        <ol className="space-y-3">
          <li className="rounded-2xl border border-line p-4">
            <p className="text-sm font-semibold text-ink">1. Allow the escrow to use {usdc(escrow.amount)} USDC</p>
            <p className="mt-1 text-xs text-muted">This approves exactly this payment amount and nothing more.</p>
            <button
              type="button"
              className="btn-ghost mt-3 w-full"
              disabled={!needsApproval || approve.busy || allowance.isLoading}
              onClick={doApprove}
            >
              {approve.busy ? <Busy label="Approving..." /> : needsApproval ? 'Approve USDC' : 'Approved'}
            </button>
            <TxStatus state={approve.state} successLabel="Allowance confirmed." />
          </li>
          <li className="rounded-2xl border border-line p-4">
            <p className="text-sm font-semibold text-ink">2. Deposit into escrow</p>
            <p className="mt-1 text-xs text-muted">
              {short
                ? `Your wallet holds ${usdc(balance.data ?? 0n)} USDC, which is not enough. Use Get test USDC in the Arc Studio sidebar, or the Circle faucet.`
                : 'The USDC is locked until you release it or a refund rule applies.'}
            </p>
            <button
              type="button"
              className="btn-primary mt-3 w-full"
              disabled={needsApproval || short || action.busy || approve.busy}
              onClick={doFund}
            >
              {action.busy ? <Busy label="Depositing..." /> : `Deposit ${usdc(escrow.amount)} USDC`}
            </button>
          </li>
        </ol>
        <TxStatus state={action.state} successLabel="Escrow updated." />
        <ConfirmButton
          label="Cancel this escrow"
          confirmLabel="Yes, cancel it"
          busy={false}
          busyLabel="Cancelling..."
          tone="ghost"
          disabled={action.busy}
          onConfirm={doCancel}
        />
      </div>
    )
  }

  // FUNDED
  const refundTime = refundAfter(escrow)
  const refundOpen = now > refundTime

  return (
    <div className="space-y-4">
      {isClient && (
        <>
          <div className="rounded-2xl border border-line p-4">
            <p className="text-sm font-semibold text-ink">Approve the work</p>
            <p className="mt-1 text-xs text-muted">
              Releasing sends {usdc(escrow.amount)} USDC to the freelancer. This cannot be undone.
            </p>
            <div className="mt-3">
              <ConfirmButton
                label="Release payment"
                confirmLabel="Confirm release"
                busy={action.busy}
                busyLabel="Releasing..."
                onConfirm={doRelease}
              />
            </div>
          </div>
          <div className="rounded-2xl border border-line p-4">
            <p className="text-sm font-semibold text-ink">Claim a refund</p>
            <p className="mt-1 text-xs text-muted">
              {refundOpen
                ? 'The refund window is open. Claiming returns the full amount to you.'
                : `Available after ${formatDateTime(refundTime)}${escrow.deadline === 0n ? ' (180 days after funding)' : ''}.`}
            </p>
            <div className="mt-3">
              <ConfirmButton
                label="Claim refund"
                confirmLabel="Confirm refund"
                busy={false}
                busyLabel="Refunding..."
                tone="ghost"
                disabled={!refundOpen || action.busy}
                onConfirm={doClaimRefund}
              />
            </div>
          </div>
        </>
      )}

      {isFreelancer && (
        <div className="rounded-2xl border border-line p-4">
          <p className="text-sm font-semibold text-ink">Return the funds</p>
          <p className="mt-1 text-xs text-muted">
            If you cannot do this job, you can send the {usdc(escrow.amount)} USDC back to the client at any time.
            Otherwise, wait for the client to release the payment.
          </p>
          <div className="mt-3">
            <ConfirmButton
              label="Refund the client"
              confirmLabel="Confirm refund"
              busy={action.busy}
              busyLabel="Refunding..."
              tone="ghost"
              onConfirm={doFreelancerRefund}
            />
          </div>
        </div>
      )}

      <TxStatus state={action.state} successLabel="Escrow updated." />
    </div>
  )
}
