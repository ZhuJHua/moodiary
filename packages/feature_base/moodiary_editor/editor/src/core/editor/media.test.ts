import { beforeEach, expect, it, vi } from 'vitest'
import { request } from '@/core/bridge/request'
import { resolveMedia, unproxyMedia } from './media'

vi.mock('@/core/bridge/request', () => ({ request: vi.fn() }))

beforeEach(() => vi.clearAllMocks())

it('can resolve media again after an earlier lookup found no local file', async () => {
  const ref = { name: 'image-retry.png' }
  vi.mocked(request).mockResolvedValueOnce({}).mockResolvedValueOnce({
    [ref.name]: 'file:///media/image-retry.png',
  })
  expect(await resolveMedia(ref)).toBeNull()
  expect(await resolveMedia(ref)).toBe('file:///media/image-retry.png')
  expect(request).toHaveBeenCalledTimes(2)
})

it('ignores malformed file URLs from clipboard HTML', () => {
  expect(unproxyMedia('file:///media/image-%ZZ.png')).toBe('')
  expect(unproxyMedia('file:///media/image-%E6%B5%B7.png')).toBe('image-海.png')
})
