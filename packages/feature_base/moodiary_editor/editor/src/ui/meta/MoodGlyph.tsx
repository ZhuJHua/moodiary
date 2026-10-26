const mouths: Record<string, string> = {
  awful: 'M16.5 17.2 s-1.6-2.7 -4.5-2.7 -4.5 2.7 -4.5 2.7 M7.6 8.6 L10 7.7 M16.4 8.6 L14 7.7',
  bad: 'M16 16.2 s-1.5-2 -4-2 -4 2 -4 2',
  okay: 'M8 15 h8',
  good: 'M8 14 s1.5 2 4 2 4-2 4-2',
  great: 'M17.5 13 a5.6 5.6 0 0 1 -11 0 z',
}

export default function MoodGlyph({
  level,
  color,
  onColor,
  size = 24,
}: {
  level?: string | null
  color?: string
  onColor?: string
  size?: number
}) {
  const mouth = level ? mouths[level] : undefined
  const eyeY = level === 'awful' ? 10.6 : 9.6
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {mouth ? <>
        <circle cx="12" cy="12" r="11.5" fill={color} />
        <g stroke={onColor}>
          <path d={`M9 ${eyeY} h0 M15 ${eyeY} h0`} strokeWidth={size < 20 ? 3 : 2.6} />
          <path d={mouth} strokeWidth={size < 20 ? 2.1 : 1.8} />
        </g>
      </> : <circle cx="12" cy="12" r="10.2" stroke="var(--app-outline)"
        strokeWidth="1.5" strokeDasharray="2.6 2.2" />}
    </svg>
  )
}
