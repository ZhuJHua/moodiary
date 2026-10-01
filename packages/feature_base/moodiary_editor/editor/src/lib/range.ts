// 原生 range 的 shadcn 配色；滑杆不走 Radix Slider，它每次值变都会把焦点抢到 thumb 上
export const rangeClass =
  'h-2 cursor-pointer appearance-none rounded-full bg-muted outline-none ' +
  '[&::-webkit-slider-thumb]:size-4 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-primary ' +
  '[&::-moz-range-thumb]:size-4 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:border-0 [&::-moz-range-thumb]:bg-primary'
