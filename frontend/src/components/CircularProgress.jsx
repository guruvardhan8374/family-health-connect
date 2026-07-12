/**
 * CircularProgress — reusable SVG ring progress indicator.
 * Props:
 *   value      0–100 (percentage)
 *   size       pixel diameter (default 120)
 *   stroke     ring thickness (default 10)
 *   color      tailwind/hex color for the filled arc
 *   trackColor ring background color
 *   label      big centre text (e.g. "72")
 *   sublabel   small centre text (e.g. "bpm")
 *   animate    animate on mount (default true)
 */
export default function CircularProgress({
  value = 0,
  size = 120,
  stroke = 10,
  color = '#14b8a6',
  trackColor = '#e2e8f0',
  label = '',
  sublabel = '',
  animate = true,
}) {
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const clamped = Math.min(Math.max(value, 0), 100);
  const offset = circumference - (clamped / 100) * circumference;
  const cx = size / 2;
  const cy = size / 2;

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        {/* Track */}
        <circle
          cx={cx} cy={cy} r={radius}
          fill="none"
          stroke={trackColor}
          strokeWidth={stroke}
        />
        {/* Progress arc */}
        <circle
          cx={cx} cy={cy} r={radius}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          style={animate ? { transition: 'stroke-dashoffset 0.8s cubic-bezier(0.4,0,0.2,1)' } : {}}
        />
      </svg>
      {/* Centre label */}
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="font-bold text-navy-900 leading-none" style={{ fontSize: size * 0.2 }}>
          {label}
        </span>
        {sublabel && (
          <span className="text-navy-400 leading-none mt-0.5" style={{ fontSize: size * 0.12 }}>
            {sublabel}
          </span>
        )}
      </div>
    </div>
  );
}
