import { Header, NetworkNotice, TestnetBanner } from '@/components/Header'
import { EmptyState } from '@/components/ui'
import { ESCROW_CONFIGURED } from '@/lib/escrow'
import { Link, RouterProvider, matchRoute, useRouter } from '@/lib/router'
import { Activity } from '@/pages/Activity'
import { Create } from '@/pages/Create'
import { Dashboard } from '@/pages/Dashboard'
import { EscrowDetails } from '@/pages/EscrowDetails'
import { Home } from '@/pages/Home'

function Routes() {
  const { path } = useRouter()
  const route = matchRoute(path)

  if (!ESCROW_CONFIGURED) {
    return (
      <EmptyState
        title="Escrow contract not configured"
        body="Set VITE_ESCROW_ADDRESS and VITE_ESCROW_DEPLOY_BLOCK in .env, then restart the dev server."
      />
    )
  }

  switch (route.name) {
    case 'home':
      return <Home />
    case 'dashboard':
      return <Dashboard />
    case 'create':
      return <Create />
    case 'activity':
      return <Activity />
    case 'escrow':
      return <EscrowDetails id={route.id} />
    default:
      return (
        <EmptyState
          title="Page not found"
          body="That page does not exist."
          action={
            <Link to="/" className="btn-primary">
              Go home
            </Link>
          }
        />
      )
  }
}

export default function App() {
  return (
    <RouterProvider>
      <div className="min-h-dvh">
        <TestnetBanner />
        <Header />
        <NetworkNotice />
        <main className="mx-auto max-w-5xl px-4 pb-24 pt-8">
          <Routes />
        </main>
        <footer className="mx-auto max-w-5xl px-4 pb-24 text-center text-xs text-subtle">
          FreelanceSafe is an experimental MVP on Arc Testnet. The contract has not been independently audited. Do not
          use real funds.
        </footer>
      </div>
    </RouterProvider>
  )
}
