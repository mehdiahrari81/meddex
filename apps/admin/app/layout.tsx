import type { Metadata } from "next";
import "./styles.css";

// Every HTML response needs the fresh CSP nonce supplied by proxy.ts.
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "MediExplain Governance",
  description: "Secure medical content and operations administration",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
