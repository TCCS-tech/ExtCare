import { Link } from "react-router-dom";
import Logo from "../Logo";

export default function Home() {
  return (
    <div className="kiosk">
      <header className="kiosk-bar">
        <Logo />
        <span className="wordmark">TCCS</span>
      </header>
      <main className="kiosk-main">
        <h1>Aftercare Checkin</h1>
        <p>Scan the QR code on a student card.</p>
        <Link className="btn btn-primary btn-kiosk" to="/checkin">
          Check in your student
        </Link>
        <Link className="btn btn-ink btn-kiosk" to="/checkout">
          Check out your student
        </Link>
      </main>
      <footer className="kiosk-foot">
        <Link to="/admin/login">Staff sign in</Link>
      </footer>
    </div>
  );
}
