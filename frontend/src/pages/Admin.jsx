import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  createStaff,
  createStudent,
  deleteStaff,
  listAttendance,
  listStaff,
  listStudents,
  logout,
  me,
  updateStudent,
} from "../api";
import Logo from "../Logo";

const emptyForm = { name: "", grade: "", student_id: "", editingId: null };

function clock(value) {
  if (!value) return "—";
  return new Date(value).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

export default function Admin() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [students, setStudents] = useState([]);
  const [roster, setRoster] = useState([]);
  const [rosterDate, setRosterDate] = useState("");
  const [staff, setStaff] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [staffForm, setStaffForm] = useState({ email: "", password: "" });
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState(null);

  async function reload() {
    const [who, studentData, day, people] = await Promise.all([
      me(),
      listStudents(),
      listAttendance(),
      listStaff(),
    ]);
    setEmail(who.email);
    setStudents(studentData.students);
    setRoster(day.attendance);
    setRosterDate(day.date);
    setStaff(people.staff);
  }

  useEffect(() => {
    let gone = false;
    reload().catch((err) => {
      if (!gone) setError(err.message);
    });
    const timer = setInterval(() => {
      listAttendance()
        .then((day) => {
          if (!gone) {
            setRoster(day.attendance);
            setRosterDate(day.date);
          }
        })
        .catch(() => {});
    }, 15000);
    return () => {
      gone = true;
      clearInterval(timer);
    };
  }, []);

  function setField(key, value) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  async function onStudent(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    setMessage("");
    try {
      if (form.editingId) {
        await updateStudent(form.editingId, { name: form.name, grade: form.grade });
        setMessage("Student updated.");
      } else {
        await createStudent({
          name: form.name,
          grade: form.grade,
          student_id: form.student_id,
        });
        setMessage("Student added.");
      }
      setForm(emptyForm);
      await reload();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function setActive(student, active) {
    setError("");
    setMessage("");
    try {
      await updateStudent(student.id, { active });
      setConfirmRemove(null);
      setMessage(active ? `${student.name} restored.` : `${student.name} removed.`);
      await reload();
    } catch (err) {
      setError(err.message);
    }
  }

  async function onStaff(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    setMessage("");
    try {
      await createStaff(staffForm.email, staffForm.password);
      setStaffForm({ email: "", password: "" });
      setMessage("Staff account added.");
      await reload();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  async function removeStaff(person) {
    setError("");
    setMessage("");
    try {
      await deleteStaff(person.id);
      setMessage(`${person.email} removed.`);
      await reload();
    } catch (err) {
      setError(err.message);
    }
  }

  async function signOut() {
    await logout();
    navigate("/admin/login", { replace: true });
  }

  return (
    <div className="container py-4">
      <header className="d-flex flex-wrap align-items-center gap-3 mb-4">
        <Logo size={40} />
        <div className="me-auto">
          <div className="wordmark">TCCS</div>
          <h1 className="h3 mb-0">Aftercare Checkin</h1>
        </div>
        <span className="text-secondary">{email}</span>
        <button className="btn btn-outline-secondary" type="button" onClick={signOut}>
          Sign out
        </button>
      </header>

      {error ? (
        <div className="alert alert-danger" role="alert">
          {error}
        </div>
      ) : null}
      {message ? (
        <div className="alert alert-success" role="status">
          {message}
        </div>
      ) : null}

      <div className="row g-4">
        <div className="col-lg-5">
          <section className="panel mb-4">
            <h2 className="h5">{form.editingId ? "Edit student" : "Add student"}</h2>
            <form onSubmit={onStudent}>
              <div className="mb-2">
                <label className="form-label" htmlFor="student-name">
                  Name
                </label>
                <input
                  id="student-name"
                  className="form-control"
                  value={form.name}
                  onChange={(event) => setField("name", event.target.value)}
                  required
                />
              </div>
              <div className="mb-2">
                <label className="form-label" htmlFor="student-grade">
                  Grade
                </label>
                <input
                  id="student-grade"
                  className="form-control"
                  placeholder="6th"
                  value={form.grade}
                  onChange={(event) => setField("grade", event.target.value)}
                  required
                />
              </div>
              <div className="mb-3">
                <label className="form-label" htmlFor="student-code">
                  Student ID
                </label>
                <input
                  id="student-code"
                  className="form-control"
                  value={form.student_id}
                  autoCapitalize="characters"
                  autoComplete="off"
                  disabled={Boolean(form.editingId)}
                  onChange={(event) => setField("student_id", event.target.value)}
                  required={!form.editingId}
                />
                <div className="form-text">Letters and numbers. This is what the QR code contains.</div>
              </div>
              <div className="d-flex gap-2">
                <button className="btn btn-primary" type="submit" disabled={busy}>
                  {busy ? "Saving…" : form.editingId ? "Save changes" : "Add student"}
                </button>
                {form.editingId ? (
                  <button className="btn btn-outline-secondary" type="button" onClick={() => setForm(emptyForm)}>
                    Cancel
                  </button>
                ) : null}
              </div>
            </form>
          </section>

          <section className="panel">
            <div className="d-flex justify-content-between align-items-baseline gap-2">
              <h2 className="h5 mb-0">Today</h2>
              <span className="text-secondary">{rosterDate}</span>
            </div>
            {roster.length === 0 ? (
              <p className="mt-3 mb-0">No one is checked in yet today.</p>
            ) : (
              <div className="table-responsive mt-3">
                <table className="table table-sm mb-0">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>In</th>
                      <th>Out</th>
                    </tr>
                  </thead>
                  <tbody>
                    {roster.map((row) => (
                      <tr key={row.student_id}>
                        <td>
                          {row.name}
                          <div className="text-secondary">{row.grade}</div>
                        </td>
                        <td>{clock(row.checkin_at)}</td>
                        <td>{clock(row.checkout_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>

        <div className="col-lg-7">
          <section className="panel">
            <div className="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
              <h2 className="h5 mb-0">Students</h2>
              <a className="btn btn-outline-secondary text-nowrap" href="/api/admin/student-cards" target="_blank" rel="noreferrer">
                Print cards
              </a>
            </div>
            {students.length === 0 ? (
              <p className="mb-0">Add a student to print cards and start check-in.</p>
            ) : (
              <div className="table-responsive">
                <table className="table align-middle mb-0">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Grade</th>
                      <th>ID</th>
                      <th>Status</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {students.map((student) => (
                      <tr key={student.id} className={student.active ? "" : "student-removed"}>
                        <td>{student.name}</td>
                        <td>{student.grade}</td>
                        <td>{student.student_id}</td>
                        <td>{student.active ? "Active" : "Removed"}</td>
                        <td className="text-end">
                          <button
                            className="btn btn-sm btn-outline-secondary me-2"
                            type="button"
                            onClick={() =>
                              setForm({
                                name: student.name,
                                grade: student.grade,
                                student_id: student.student_id,
                                editingId: student.id,
                              })
                            }
                          >
                            Edit
                          </button>
                          {student.active ? (
                            confirmRemove === student.id ? (
                              <>
                                <span className="me-2">Remove {student.name}?</span>
                                <button className="btn btn-sm btn-danger me-2" type="button" onClick={() => setActive(student, false)}>
                                  Remove
                                </button>
                                <button className="btn btn-sm btn-outline-secondary" type="button" onClick={() => setConfirmRemove(null)}>
                                  Cancel
                                </button>
                              </>
                            ) : (
                              <button className="btn btn-sm btn-outline-danger" type="button" onClick={() => setConfirmRemove(student.id)}>
                                Remove
                              </button>
                            )
                          ) : (
                            <button className="btn btn-sm btn-outline-primary" type="button" onClick={() => setActive(student, true)}>
                              Restore
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          <section className="panel mt-4">
            <h2 className="h5">Staff accounts</h2>
            <ul className="list-unstyled mb-3">
              {staff.map((person) => (
                <li key={person.id} className="d-flex justify-content-between align-items-center gap-2 py-1">
                  <span>{person.email}</span>
                  {person.email === email ? (
                    <span className="text-secondary">Signed in</span>
                  ) : (
                    <button className="btn btn-sm btn-outline-danger" type="button" onClick={() => removeStaff(person)}>
                      Remove
                    </button>
                  )}
                </li>
              ))}
            </ul>
            <form onSubmit={onStaff} className="row g-2">
              <div className="col-md-5">
                <label className="form-label" htmlFor="staff-email">
                  Email
                </label>
                <input
                  id="staff-email"
                  type="email"
                  className="form-control"
                  autoComplete="off"
                  value={staffForm.email}
                  onChange={(event) => setStaffForm({ ...staffForm, email: event.target.value })}
                  required
                />
              </div>
              <div className="col-md-5">
                <label className="form-label" htmlFor="staff-password">
                  Password
                </label>
                <input
                  id="staff-password"
                  type="password"
                  className="form-control"
                  autoComplete="new-password"
                  value={staffForm.password}
                  onChange={(event) => setStaffForm({ ...staffForm, password: event.target.value })}
                  required
                  minLength={8}
                />
              </div>
              <div className="col-md-2 d-flex align-items-end">
                <button className="btn btn-primary w-100" type="submit" disabled={busy}>
                  Add
                </button>
              </div>
            </form>
          </section>
          <p className="mt-3 mb-0">
            <Link to="/">Parent check-in</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
