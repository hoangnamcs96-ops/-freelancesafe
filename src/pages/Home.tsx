import { ArrowRight, BadgeCheck, Lock, Send, UserCheck } from 'lucide-react'
import { Link } from '@/lib/router'
import { CHAIN, ESCROW_ADDRESS, USDC_ADDRESS } from '@/lib/escrow'
import { AddressLink } from '@/components/ui'

const STEPS = [
  {
    icon: Send,
    title: 'Create the job',
    body: 'The client writes down the work, the freelancer wallet, the payment in test USDC, and an optional deadline.',
  },
  {
    icon: Lock,
    title: 'Lock the payment',
    body: 'The client deposits the USDC into the escrow contract. The freelancer can see it is funded before starting.',
  },
  {
    icon: UserCheck,
    title: 'Approve the work',
    body: 'When the work is done, only the client can release the funds. Nobody else, including us, can move them.',
  },
  {
    icon: BadgeCheck,
    title: 'Get paid',
    body: 'The USDC goes straight to the freelancer wallet and the escrow is closed for good.',
  },
]

const RULES = [
  'An unfunded escrow can be cancelled by the client who created it.',
  'Once funded, only the client can release the payment to the freelancer.',
  'The freelancer can send the money back to the client at any time.',
  'With a deadline, the client can claim a refund only after the deadline has passed.',
  'Without a deadline, the client can claim a refund 180 days after funding. This is a safety net so funds never stay locked forever.',
  'After a release, refund, or cancellation the escrow is closed. Nothing can be paid twice.',
  'There is no admin key and no hidden withdrawal function.',
]

export function Home() {
  return (
    <div className="space-y-14">
      <section className="grid items-center gap-8 pt-4 md:grid-cols-[1.15fr_1fr]">
        <div>
          <p className="mb-3 inline-flex rounded-full bg-brand-soft px-3 py-1 text-xs font-semibold uppercase tracking-[0.08em] text-brand-dark">
            Experimental MVP
          </p>
          <h1 className="text-4xl font-bold leading-[1.05] text-ink sm:text-5xl">
            Pay when the work is done. Get paid for the work you did.
          </h1>
          <p className="mt-4 max-w-lg text-base text-muted">
            Clients worry about paying before they see results. Freelancers worry about finishing work and never
            being paid. FreelanceSafe holds the client's USDC in a smart contract until the client approves the work.
          </p>
          <div className="mt-7 flex flex-wrap gap-3">
            <Link to="/create" className="btn-primary">
              Create an escrow <ArrowRight className="size-4" aria-hidden />
            </Link>
            <Link to="/dashboard" className="btn-ghost">
              Open dashboard
            </Link>
          </div>
        </div>

        <div className="card p-6">
          <h2 className="text-lg font-semibold text-ink">The escrow rules</h2>
          <ul className="mt-3 space-y-2.5">
            {RULES.map((rule) => (
              <li key={rule} className="flex gap-2.5 text-sm text-muted">
                <span className="mt-2 size-1.5 shrink-0 rounded-full bg-brand" aria-hidden />
                {rule}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section aria-labelledby="how">
        <h2 id="how" className="mb-5 text-2xl font-bold text-ink">
          How it works
        </h2>
        <ol className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {STEPS.map((step, i) => (
            <li key={step.title} className="card p-5">
              <div className="flex items-center gap-3">
                <span className="flex size-10 items-center justify-center rounded-xl bg-navy text-white">
                  <step.icon className="size-5" aria-hidden />
                </span>
                <span className="font-mono text-xs text-subtle">0{i + 1}</span>
              </div>
              <h3 className="mt-4 text-base font-semibold text-ink">{step.title}</h3>
              <p className="mt-1.5 text-sm text-muted">{step.body}</p>
            </li>
          ))}
        </ol>
      </section>

      <section className="card grid gap-5 p-6 sm:grid-cols-2" aria-labelledby="onchain">
        <div>
          <h2 id="onchain" className="text-lg font-semibold text-ink">
            Where this runs
          </h2>
          <p className="mt-1.5 text-sm text-muted">
            {CHAIN.name} with test USDC only. This contract has not been independently audited and is not production
            ready. Never use real funds.
          </p>
        </div>
        <dl className="space-y-3 text-sm">
          <div className="flex items-center justify-between gap-3">
            <dt className="text-subtle">Escrow contract</dt>
            <dd>
              <AddressLink address={ESCROW_ADDRESS} />
            </dd>
          </div>
          <div className="flex items-center justify-between gap-3">
            <dt className="text-subtle">USDC token (Arc)</dt>
            <dd>
              <AddressLink address={USDC_ADDRESS} />
            </dd>
          </div>
        </dl>
      </section>
    </div>
  )
}
