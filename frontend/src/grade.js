export function gradePhrase(grade) {
  const value = (grade || "").trim();
  const lower = value.toLowerCase();
  if (!value) return "unknown grade";
  if (lower.includes("grade")) return value;
  if (lower === "k" || lower === "kindergarten") return "Kindergarten";
  if (lower.startsWith("pre")) return value;
  return `${value} grade`;
}

export function confirmSentence(action, name, grade) {
  const verb = action === "checkout" ? "Check out" : "Check in";
  return `${verb} ${name.trim()} (${gradePhrase(grade)})?`;
}
