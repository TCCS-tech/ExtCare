import { useEffect, useId, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { Html5Qrcode } from "html5-qrcode";
import { checkIn, checkOut, lookupStudent } from "../api";
import { confirmSentence } from "../grade";
import Logo from "../Logo";

export default function Scan({ mode }) {
  const action = mode === "checkout" ? "checkout" : "checkin";
  const title = action === "checkin" ? "Check in" : "Check out";
  const titleId = useId();
  const confirmRef = useRef(null);
  const handleRef = useRef(() => {});
  const lock = useRef(false);
  const recent = useRef({ value: "", at: 0 });

  const [cameraError, setCameraError] = useState("");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);
  const [manual, setManual] = useState("");
  const [modal, setModal] = useState(null);
  const [banner, setBanner] = useState(null);

  handleRef.current = (raw) => {
    const text = (raw || "").trim();
    if (!text) return;
    const now = Date.now();
    if (recent.current.value === text && now - recent.current.at < 2500) {
      lock.current = false;
      return;
    }
    recent.current = { value: text, at: now };
    openFor(text);
  };

  useEffect(() => {
    let scanner;
    let cancelled = false;
    const failCamera = () => {
      if (!cancelled) {
        setCameraError("The camera is unavailable. Type the student ID from the card.");
      }
    };
    try {
      if (!document.getElementById("qr-reader")) {
        failCamera();
        return undefined;
      }
      scanner = new Html5Qrcode("qr-reader");
      const pending = scanner.start(
        { facingMode: "environment" },
        { fps: 8, qrbox: { width: 220, height: 220 } },
        (text) => {
          if (lock.current) return;
          lock.current = true;
          handleRef.current(text);
        },
        () => {},
      );
      Promise.resolve(pending)
        .then(() => {
          if (cancelled) return scanner.stop();
          return undefined;
        })
        .catch(failCamera);
    } catch {
      failCamera();
    }
    return () => {
      cancelled = true;
      if (!scanner) return undefined;
      Promise.resolve()
        .then(() => scanner.stop())
        .catch(() => {})
        .then(() => {
          try {
            scanner.clear();
          } catch {
            /* scanner already stopped */
          }
        });
      return undefined;
    };
  }, [action]);

  useEffect(() => {
    if (!modal) return undefined;
    confirmRef.current?.focus();
    function onKey(event) {
      if (event.key === "Escape") dismiss();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [modal]);

  async function openFor(raw) {
    setBanner(null);
    setStatus("Looking up that student…");
    setBusy(true);
    try {
      const student = await lookupStudent(raw);
      setModal({ student, phase: phaseFor(student) });
      setStatus("");
    } catch (err) {
      setBanner({ kind: "error", text: err.message });
      setStatus("");
      lock.current = false;
    } finally {
      setBusy(false);
    }
  }

  function phaseFor(student) {
    if (action === "checkin" && student.checked_in) return "already-in";
    if (action === "checkout" && !student.checked_in) return "not-in";
    if (action === "checkout" && student.checked_out) return "already-out";
    return "confirm";
  }

  function dismiss() {
    setModal(null);
    lock.current = false;
  }

  async function confirm() {
    if (!modal) return;
    setBusy(true);
    try {
      const id = modal.student.student_id;
      const result = action === "checkin" ? await checkIn(id) : await checkOut(id);
      const stamp = action === "checkin" ? result.checkin_at : result.checkout_at;
      const when = new Date(stamp).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
      const verb = action === "checkin" ? "Checked in" : "Checked out";
      setBanner({ kind: "success", text: `${verb} ${result.name} at ${when}.` });
      setModal(null);
    } catch (err) {
      setBanner({ kind: "error", text: err.message });
      setModal(null);
    } finally {
      setBusy(false);
      lock.current = false;
    }
  }

  function onManual(event) {
    event.preventDefault();
    if (!manual.trim() || lock.current) return;
    lock.current = true;
    recent.current = { value: manual.trim(), at: Date.now() };
    openFor(manual);
  }

  const student = modal?.student;
  let prompt = "";
  if (student && modal.phase === "confirm") {
    prompt = confirmSentence(action, student.name, student.grade);
  } else if (student && modal.phase === "already-in") {
    prompt = `${student.name} is already checked in today.`;
  } else if (student && modal.phase === "not-in") {
    prompt = `${student.name} is not checked in today.`;
  } else if (student && modal.phase === "already-out") {
    prompt = `${student.name} is already checked out today.`;
  }

  return (
    <div className="scan-shell">
      <header className="topbar mb-3">
        <Logo size={36} />
        <Link to="/">Back</Link>
      </header>
      <h1 className="h2 mb-2">{title}</h1>
      <p className="text-secondary">Hold the student card QR code in front of the camera.</p>
      <div id="qr-reader" />
      {cameraError ? <p className="text-secondary">{cameraError}</p> : null}
      {status ? <p role="status">{status}</p> : null}
      {banner ? (
        <div className={`alert ${banner.kind === "success" ? "alert-success" : "alert-danger"}`} role={banner.kind === "success" ? "status" : "alert"}>
          {banner.text}
        </div>
      ) : null}
      <form onSubmit={onManual} className="mt-3">
        <label htmlFor="student-id" className="form-label">
          Or enter the student ID
        </label>
        <div className="input-group">
          <input
            id="student-id"
            className="form-control"
            value={manual}
            autoCapitalize="characters"
            autoComplete="off"
            onChange={(event) => setManual(event.target.value)}
          />
          <button className="btn btn-primary" type="submit" disabled={busy || !manual.trim()}>
            Look up
          </button>
        </div>
      </form>

      {modal ? (
        <>
          <div className="modal-backdrop fade show" onClick={dismiss} />
          <div className="modal d-block" role="dialog" aria-modal="true" aria-labelledby={titleId}>
            <div className="modal-dialog modal-dialog-centered">
              <div className="modal-content" onClick={(event) => event.stopPropagation()}>
                <div className="modal-header">
                  <h2 className="modal-title h5" id={titleId}>
                    {title}
                  </h2>
                </div>
                <div className="modal-body">
                  <p className="mb-1 fs-5">{prompt}</p>
                  <p className="mb-0 text-secondary">ID {student.student_id}</p>
                </div>
                <div className="modal-footer">
                  {modal.phase === "confirm" ? (
                    <button ref={confirmRef} className="btn btn-primary" type="button" onClick={confirm} disabled={busy}>
                      {busy ? "Saving…" : "Confirm"}
                    </button>
                  ) : null}
                  <button
                    ref={modal.phase === "confirm" ? undefined : confirmRef}
                    className="btn btn-outline-secondary"
                    type="button"
                    onClick={dismiss}
                  >
                    {modal.phase === "confirm" ? "Cancel" : "OK"}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}
