import { useMemo, useState, type FormEvent } from 'react'
import { useAccount } from 'wagmi'
import { ConnectKitButton } from 'connectkit'
import { isAddress, parseEventLogs } from 'viem'
import { Loader2 } from 'lucide-react'
import { escrowAbi } from '@/lib/escrowAbi'
import { CHAIN_ID, ESCROW_ADDRESS, USDC_ADDRESS, sameAddress } from '@/lib/escrow'
import { useRouter } from '@/lib/router'
import { utf8Length } from '@/lib/format'
import { parseUsdc } from '@/onchain-money'
import { useTx } from '@/hooks/useTx'
import { useNowMs } from '@/hooks/useNow'
import { PageTitle, TxStatus } from '@/components/ui'

const SYSTEM_EMITTER = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE'

function freelancerProblem(value: string, client?: string): string | null {
  if (!value) return null
  if (!isAddress(value)) return 'Enter a valid wallet address (0x followed by 40 characters).'
  if (sameAddress(value, client)) return 'The freelancer must be a different wallet than yours.'
  if (sameAddress(value, ESCROW_ADDRESS) || sameAddress(value, USDC_ADDRESS) || sameAddress(value, SYSTEM_EMITTER)) {
    return 'That address is a system or contract address and cannot receive a payment.'
  }
  if (BigInt(value) <= 0xffffn) return 'That address is reserved and cannot receive a payment.'
  return null
}

export function Create() {
  const { address, isConnected } = useAccount()
  const { navigate } = useRouter()
  const { state, run, busy } = useTx()
  const nowMs = useNowMs()

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [freelancer, setFreelancer] = useState('')
  const [amount, setAmount] = useState('')
  const [deadline, setDeadline] = useState('')

  const problems = useMemo(() => {
    const out: Partial<Record<'title' | 'description' | 'freelancer' | 'amount' | 'deadline', string>> = {}
    if (title && utf8Length(title) > 100) out.title = 'Title must be 100 bytes or fewer.'
    if (utf8Length(description) > 1000) out.description = 'Description must be 1000 bytes or fewer.'
    out.freelancer = freelancerProblem(freelancer, address) ?? undefined
    if (amount) {
      try {
        if (parseUsdc(amount) <= 0n) out.amount = 'Amount must be greater than zero.'
      } catch {
        out.amount = 'Enter a USDC amount with at most 6 decimals.'
      }
    }
    if (deadline && new Date(deadline).getTime() <= nowMs + 60_000) out.deadline = 'Pick a deadline in the future.'
    return out
  }, [title, description, freelancer, amount, deadline, address, nowMs])

  const hasProblems = Object.values(problems).some(Boolean)
  const complete = title.trim().length > 0 && isAddress(freelancer) && amount.length > 0

  const submit = async () => {
    if (hasProblems || !complete || !isAddress(freelancer)) return
    const amountRaw = parseUsdc(amount)
    const deadlineSeconds = deadline ? BigInt(Math.floor(new Date(deadline).getTime() / 1000)) : 0n
    const receipt = await run((write) =>
      write({
        address: ESCROW_ADDRESS,
        abi: escrowAbi,
        functionName: 'createEscrow',
        args: [freelancer, amountRaw, deadlineSeconds, title.trim(), description.trim()],
        chainId: CHAIN_ID,
      }),
    )
    if (!receipt) return
    const created = parseEventLogs({ abi: escrowAbi, logs: receipt.logs, eventName: 'EscrowCreated' })[0]
    if (created) navigate(`/escrow/${created.args.id.toString()}`)
  }

  const onSubmit = (event: FormEvent) => {
    event.preventDefault()
    void submit()
  }

  const minDeadline = new Date(nowMs + 5 * 60_000 - new Date(nowMs).getTimezoneOffset() * 60_000)
    .toISOString()
    .slice(0, 16)

  return (
    <div className="mx-auto max-w-2xl">
      <PageTitle
        title="Create an escrow"
        subtitle="Describe the job and the payment. You will deposit the USDC in the next step."
      />

      <form onSubmit={onSubmit} className="card space-y-5 p-6" noValidate>
        <div>
          <label htmlFor="title" className="label">
            Job title
          </label>
          <input
            id="title"
            className="field"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Landing page redesign"
            maxLength={100}
            autoComplete="off"
          />
          {problems.title && <p className="mt-1.5 text-xs font-medium text-bad">{problems.title}</p>}
        </div>

        <div>
          <label htmlFor="description" className="label">
            Description
          </label>
          <textarea
            id="description"
            className="field min-h-28 resize-y"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="What will be delivered, and what counts as done?"
          />
          {problems.description && <p className="mt-1.5 text-xs font-medium text-bad">{problems.description}</p>}
        </div>

        <div>
          <label htmlFor="freelancer" className="label">
            Freelancer wallet address
          </label>
          <input
            id="freelancer"
            className="field font-mono !text-[13px]"
            value={freelancer}
            onChange={(e) => setFreelancer(e.target.value.trim())}
            placeholder="0x..."
            spellCheck={false}
            autoComplete="off"
          />
          {problems.freelancer && <p className="mt-1.5 text-xs font-medium text-bad">{problems.freelancer}</p>}
          <p className="mt-1.5 text-xs text-subtle">Double check this address. The payment can only go to this wallet.</p>
        </div>

        <div className="grid gap-5 sm:grid-cols-2">
          <div>
            <label htmlFor="amount" className="label">
              Payment (test USDC)
            </label>
            <div className="relative">
              <input
                id="amount"
                className="field tabular pr-16"
                inputMode="decimal"
                value={amount}
                onChange={(e) => {
                  const v = e.target.value
                  if (v === '' || /^\d*\.?\d*$/.test(v)) setAmount(v)
                }}
                placeholder="0.00"
                autoComplete="off"
              />
              <span className="pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-xs font-semibold text-subtle">
                USDC
              </span>
            </div>
            {problems.amount && <p className="mt-1.5 text-xs font-medium text-bad">{problems.amount}</p>}
          </div>
          <div>
            <label htmlFor="deadline" className="label">
              Deadline (optional)
            </label>
            <input
              id="deadline"
              type="datetime-local"
              className="field"
              value={deadline}
              min={minDeadline}
              onChange={(e) => setDeadline(e.target.value)}
            />
            {problems.deadline && <p className="mt-1.5 text-xs font-medium text-bad">{problems.deadline}</p>}
          </div>
        </div>

        <div className="rounded-2xl bg-canvas p-4 text-sm text-muted">
          <p className="font-semibold text-ink">Payment and refund conditions</p>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>Only you, as the client, can release the payment to the freelancer.</li>
            <li>Until you deposit, you can cancel this escrow.</li>
            <li>After the deposit, the freelancer can send the money back at any time.</li>
            <li>
              {deadline
                ? 'You can claim a refund only after the deadline has passed.'
                : 'With no deadline, you can claim a refund 180 days after the deposit.'}
            </li>
          </ul>
        </div>

        {!isConnected ? (
          <ConnectKitButton.Custom>
            {({ show }) => (
              <button type="button" className="btn-primary w-full" onClick={show}>
                Connect wallet to continue
              </button>
            )}
          </ConnectKitButton.Custom>
        ) : (
          <button type="submit" className="btn-primary w-full" disabled={busy || hasProblems || !complete}>
            {busy ? (
              <>
                <Loader2 className="size-4 animate-spin" aria-hidden />
                {state.phase === 'wallet' ? 'Confirm in your wallet...' : 'Creating escrow...'}
              </>
            ) : (
              'Create escrow'
            )}
          </button>
        )}

        <TxStatus state={state} successLabel="Escrow created. Opening it now..." />
      </form>
    </div>
  )
}
