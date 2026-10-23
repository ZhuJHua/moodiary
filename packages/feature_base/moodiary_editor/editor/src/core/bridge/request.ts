import { post } from './post'

let seq = 0
const waiting = new Map<string, (value: unknown) => void>()

export function request<T>(type: string, payload: object = {}): Promise<T> {
  const reqId = `r${++seq}`
  return new Promise<T>((resolve) => {
    waiting.set(reqId, resolve as (value: unknown) => void)
    post(type, { ...payload, reqId })
  })
}

export function respond(reqId: string, json: string): void {
  const resolve = waiting.get(reqId)
  if (!resolve) return
  waiting.delete(reqId)
  resolve(JSON.parse(json))
}
