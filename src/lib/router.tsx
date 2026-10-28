import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type AnchorHTMLAttributes,
  type MouseEvent,
  type ReactNode,
} from 'react'

interface RouterValue {
  path: string
  navigate: (to: string) => void
}

const RouterContext = createContext<RouterValue | null>(null)

export function RouterProvider({ children }: { children: ReactNode }) {
  const [path, setPath] = useState(() => window.location.pathname)

  useEffect(() => {
    const onPop = () => setPath(window.location.pathname)
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [])

  const navigate = useCallback((to: string) => {
    if (to !== window.location.pathname) window.history.pushState({}, '', to)
    setPath(window.location.pathname)
    window.scrollTo(0, 0)
  }, [])

  const value = useMemo(() => ({ path, navigate }), [path, navigate])
  return <RouterContext.Provider value={value}>{children}</RouterContext.Provider>
}

export function useRouter(): RouterValue {
  const ctx = useContext(RouterContext)
  if (!ctx) throw new Error('useRouter must be used inside RouterProvider')
  return ctx
}

export function Link({ to, onClick, children, ...rest }: AnchorHTMLAttributes<HTMLAnchorElement> & { to: string }) {
  const { navigate } = useRouter()
  const handle = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event)
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey) return
    event.preventDefault()
    navigate(to)
  }
  return (
    <a href={to} onClick={handle} {...rest}>
      {children}
    </a>
  )
}

export type Route =
  | { name: 'home' }
  | { name: 'dashboard' }
  | { name: 'create' }
  | { name: 'activity' }
  | { name: 'escrow'; id: bigint }
  | { name: 'notfound' }

export function matchRoute(path: string): Route {
  const clean = path.replace(/\/+$/, '') || '/'
  if (clean === '/') return { name: 'home' }
  if (clean === '/dashboard') return { name: 'dashboard' }
  if (clean === '/create') return { name: 'create' }
  if (clean === '/activity') return { name: 'activity' }
  const m = /^\/escrow\/(\d{1,18})$/.exec(clean)
  if (m) return { name: 'escrow', id: BigInt(m[1]) }
  return { name: 'notfound' }
}
