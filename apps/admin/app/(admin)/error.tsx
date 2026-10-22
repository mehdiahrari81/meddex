"use client";
export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) { return <section className="card empty" role="alert"><h1>Could not load this page</h1><p>Check your connection and try again. If the problem continues, ask your administrator to check your access.</p><button onClick={reset}>Try again</button></section>; }
