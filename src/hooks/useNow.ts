import { useEffect, useState } from 'react'

/** Wall-clock time in milliseconds, refreshed on an interval so render stays pure. */
export function useNowMs(intervalMs = 15_000): number {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), intervalMs)
    return () => window.clearInterval(id)
  }, [intervalMs])
  return now
}
