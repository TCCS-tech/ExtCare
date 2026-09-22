import { useEffect, useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { login, me } from "../api";
import Logo from "../Logo";

export default function AdminLogin() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [ready, setReady] = useState("loading");

  useEffect(() => {
    let gone = false;
    me()
      .then(() => {
        if (!gone) setReady("in");
      })
      .catch(() => {
        if (!gone) setReady("out");
      });
    return () => {
      gone = true;
    };
  }, []);

  async function onSubmit(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      await login(email, password);
      setReady("in");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (ready === "in") return <Navigate to="/admin" replace />;
  if (ready === "loading") return <p className="p-4">Checking sign-in…</p>;

  return (
    <div className="scan-shell">
      <header className="topbar mb-4">
        <Logo size={36} />
        <Link to="/">Back</Link>
      </header>
      <h1 className="h2">Staff sign in</h1>
      <form className="panel mt-3" onSubmit={onSubmit}>
        {error ? (
          <div className="alert alert-danger" role="alert">
            {error}
          </div>
        ) : null}
        <div className="mb-3">
          <label className="form-label" htmlFor="email">
            Email
          </label>
          <input
            id="email"
            type="email"
            className="form-control"
            autoComplete="username"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </div>
        <div className="mb-3">
          <label className="form-label" htmlFor="password">
            Password
          </label>
          <input
            id="password"
            type="password"
            className="form-control"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </div>
        <button className="btn btn-primary" type="submit" disabled={busy}>
          {busy ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </div>
  );
}
