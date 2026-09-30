import { useSyncExternalStore } from 'react'

export interface Store<T> {
  get(): T
  set(next: T): void
  patch(partial: Partial<T>): void
  subscribe(listener: () => void): () => void
}

export function createStore<T>(initial: T): Store<T> {
  let state = initial
  const listeners = new Set<() => void>()
  const emit = (): void => listeners.forEach((l) => l())
  return {
    get: () => state,
    set: (next) => {
      if (Object.is(next, state)) return
      state = next
      emit()
    },
    patch: (partial) => {
      state = { ...state, ...partial }
      emit()
    },
    subscribe: (listener) => {
      listeners.add(listener)
      return () => {
        listeners.delete(listener)
      }
    },
  }
}

// selector 须返回原始值或稳定引用，否则 useSyncExternalStore 会无限重渲染
export function useStore<T>(store: Store<T>): T
export function useStore<T, S>(store: Store<T>, selector: (state: T) => S): S
export function useStore<T, S>(store: Store<T>, selector?: (state: T) => S): T | S {
  return useSyncExternalStore(store.subscribe, () =>
    selector ? selector(store.get()) : store.get(),
  )
}
