export default function Logo({ size = 48 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <rect width="64" height="64" rx="8" fill="#1f4e3d" />
      <path d="M14 40 V26 L32 16 L50 26 V40" fill="none" stroke="#f4f0e6" strokeWidth="3" />
      <path d="M24 40 V30 H40 V40" fill="none" stroke="#f4f0e6" strokeWidth="3" />
    </svg>
  );
}
