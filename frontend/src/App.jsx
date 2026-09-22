import { Component, lazy, Suspense, useEffect, useState } from "react";
import { Link, Navigate, Outlet, Route, Routes } from "react-router-dom";
import { me } from "./api";
import Home from "./pages/Home";
import AdminLogin from "./pages/AdminLogin";
import Admin from "./pages/Admin";

const Scan = lazy(() => import("./pages/Scan"));

class ScanBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { failed: false };
  }

  static getDerivedStateFromError() {
    return { failed: true };
  }

  render() {
    if (this.state.failed) {
      return (
        <div className="scan-shell">
          <p>The scanner hit a problem.</p>
          <p>
            <Link to="/">Back</Link>
          </p>
        </div>
      );
    }
    return this.props.children;
  }
}

function RequireStaff() {
  const [state, setState] = useState("loading");

  useEffect(() => {
    let gone = false;
    me()
      .then(() => {
        if (!gone) setState("in");
      })
      .catch(() => {
        if (!gone) setState("out");
      });
    return () => {
      gone = true;
    };
  }, []);

  if (state === "loading") {
    return <p className="p-4">Checking sign-in…</p>;
  }
  if (state === "out") {
    return <Navigate to="/admin/login" replace />;
  }
  return <Outlet />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route
        path="/checkin"
        element={
          <Suspense fallback={<p className="p-4">Opening the camera…</p>}>
            <ScanBoundary>
              <Scan mode="checkin" />
            </ScanBoundary>
          </Suspense>
        }
      />
      <Route
        path="/checkout"
        element={
          <Suspense fallback={<p className="p-4">Opening the camera…</p>}>
            <ScanBoundary>
              <Scan mode="checkout" />
            </ScanBoundary>
          </Suspense>
        }
      />
      <Route path="/admin/login" element={<AdminLogin />} />
      <Route element={<RequireStaff />}>
        <Route path="/admin" element={<Admin />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
