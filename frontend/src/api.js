export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

async function request(path, options = {}) {
  const headers = new Headers(options.headers || {});
  if (options.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  const response = await fetch(path, {
    ...options,
    headers,
    credentials: "same-origin",
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { error: text };
    }
  }
  if (!response.ok) {
    throw new ApiError(data?.error || "Something went wrong.", response.status);
  }
  return data;
}

export function lookupStudent(studentId) {
  return request(`/api/students/${encodeURIComponent(studentId.trim())}`);
}

export function checkIn(studentId) {
  return request("/api/checkin", {
    method: "POST",
    body: JSON.stringify({ student_id: studentId }),
  });
}

export function checkOut(studentId) {
  return request("/api/checkout", {
    method: "POST",
    body: JSON.stringify({ student_id: studentId }),
  });
}

export function login(email, password) {
  return request("/api/admin/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export function logout() {
  return request("/api/admin/logout", { method: "POST" });
}

export function me() {
  return request("/api/admin/me");
}

export function listStudents() {
  return request("/api/admin/students");
}

export function createStudent(student) {
  return request("/api/admin/students", {
    method: "POST",
    body: JSON.stringify(student),
  });
}

export function updateStudent(id, patch) {
  return request(`/api/admin/students/${id}`, {
    method: "PATCH",
    body: JSON.stringify(patch),
  });
}

export function listAttendance() {
  return request("/api/admin/attendance");
}

export function listStaff() {
  return request("/api/admin/staff");
}

export function createStaff(email, password) {
  return request("/api/admin/staff", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export function deleteStaff(id) {
  return request(`/api/admin/staff/${id}`, { method: "DELETE" });
}
