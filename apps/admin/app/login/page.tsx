import { LoginForm } from "./login-form";
import { BrandMark, Icon } from "@/components/icon";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ expired?: string }>;
}) {
  const { expired } = await searchParams;
  return (
    <main className="login-shell">
      <aside className="login-story">
        <div className="brand">
          <BrandMark />
          <div>
            MediExplain<span>Governance workspace</span>
          </div>
        </div>
        <div className="login-story-copy">
          <span className="login-story-label">
            Clarity starts with trusted content.
          </span>
          <h2>
            A careful workspace
            <br />
            for clearer care.
          </h2>
          <p>
            Give every definition, translation, and learning resource the review
            it deserves.
          </p>
          <div className="login-principles">
            <span>
              <Icon name="check" size={17} />
              Independent content review
            </span>
            <span>
              <Icon name="globe" size={17} />
              Visible source provenance
            </span>
            <span>
              <Icon name="shield" size={17} />
              Audited, accountable changes
            </span>
          </div>
        </div>
        <p className="login-story-footer">
          Medical literacy, thoughtfully governed.
        </p>
      </aside>
      <section className="login-card" aria-labelledby="login-title">
        <span className="login-lock">
          <Icon name="lock" size={23} />
        </span>
        <p className="eyebrow">Administrative access</p>
        <h1 id="login-title">Welcome back.</h1>
        <p className="login-description">
          Sign in to your MediExplain workspace.
        </p>
        {expired ? (
          <p className="error" role="status">
            Your administrative session expired. Sign in again.
          </p>
        ) : null}
        <LoginForm />
        <p className="login-security">
          <Icon name="shield" size={15} />
          Access is limited to authorized team members.
        </p>
      </section>
    </main>
  );
}
