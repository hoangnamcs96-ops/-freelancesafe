import { ConnectKitButton } from 'connectkit'
import { useAccount, useSwitchChain } from 'wagmi'
import { AlertTriangle, ShieldCheck, Wallet } from 'lucide-react'
import { Link, useRouter } from '@/lib/router'
import { CHAIN, CHAIN_ID } from '@/lib/escrow'
import { shortAddress, usdc } from '@/lib/format'
import { useUsdcBalance } from '@/hooks/useUsdc'

const NAV = [
  { to: '/', label: 'Home' },
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/create', label: 'Create' },
  { to: '/activity', label: 'Activity' },
]

export function TestnetBanner() {
  return (
    <div className="bg-navy-deep px-4 py-2 text-center text-xs font-semibold tracking-wide text-white">
      Arc Testnet — Test Tokens Only. No Real Funds.
    </div>
  )
}

function WalletArea() {
  const { address, chainId, isConnected } = useAccount()
  const balance = useUsdcBalance(address)
  const onArc = chainId === CHAIN_ID

  return (
    <ConnectKitButton.Custom>
      {({ show, isConnecting }) =>
        isConnected && address ? (
          <div className="flex items-center gap-2">
            {onArc && balance.data !== undefined && (
              <span className="tabular hidden rounded-full bg-brand-soft px-3 py-1.5 text-xs font-semibold text-brand-dark sm:inline">
                {usdc(balance.data)} USDC
              </span>
            )}
            <span
              className={`hidden rounded-full px-3 py-1.5 text-xs font-semibold ring-1 ring-inset md:inline ${
                onArc ? 'bg-emerald-50 text-ok ring-emerald-200' : 'bg-amber-50 text-warn ring-amber-200'
              }`}
            >
              {onArc ? CHAIN.name : 'Wrong network'}
            </span>
            <button type="button" onClick={show} className="btn-ghost font-mono !text-[13px]">
              <Wallet className="size-4" aria-hidden />
              {shortAddress(address)}
            </button>
          </div>
        ) : (
          <button type="button" onClick={show} className="btn-primary" disabled={isConnecting}>
            <Wallet className="size-4" aria-hidden />
            {isConnecting ? 'Connecting...' : 'Connect wallet'}
          </button>
        )
      }
    </ConnectKitButton.Custom>
  )
}

export function NetworkNotice() {
  const { isConnected, chainId } = useAccount()
  const { switchChain, isPending } = useSwitchChain()
  if (!isConnected || chainId === CHAIN_ID) return null
  return (
    <div className="border-b border-amber-200 bg-amber-50">
      <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-4 py-3">
        <p className="flex items-center gap-2 text-sm font-medium text-warn">
          <AlertTriangle className="size-4 shrink-0" aria-hidden />
          Your wallet is on a different network. FreelanceSafe runs on {CHAIN.name}.
        </p>
        <button
          type="button"
          className="btn-primary !min-h-9 !py-1.5"
          disabled={isPending}
          onClick={() => switchChain({ chainId: CHAIN_ID })}
        >
          {isPending ? 'Check your wallet...' : `Switch to ${CHAIN.name}`}
        </button>
      </div>
    </div>
  )
}

export function Header() {
  const { path } = useRouter()
  const isActive = (to: string) => (to === '/' ? path === '/' : path.startsWith(to))

  return (
    <header className="sticky top-0 z-30 border-b border-line bg-white/90 backdrop-blur">
      <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-x-6 gap-y-2 px-4 py-3">
        <Link to="/" className="flex items-center gap-2">
          <span className="flex size-9 items-center justify-center rounded-xl bg-navy text-white">
            <ShieldCheck className="size-5" aria-hidden />
          </span>
          <span className="font-display text-lg font-bold tracking-tight text-ink">FreelanceSafe</span>
        </Link>

        <nav aria-label="Main" className="order-3 -mx-1 flex w-full gap-1 overflow-x-auto sm:order-none sm:mx-0 sm:w-auto">
          {NAV.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              aria-current={isActive(item.to) ? 'page' : undefined}
              className={`min-h-11 whitespace-nowrap rounded-lg px-3.5 py-2.5 text-sm font-semibold transition ${
                isActive(item.to) ? 'bg-brand-soft text-brand-dark' : 'text-muted hover:text-ink'
              }`}
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <WalletArea />
      </div>
    </header>
  )
}
