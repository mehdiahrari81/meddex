import type { ReactNode } from "react";
import { Icon } from "./icon";

export { DataTable } from "./data-table";
export { Value } from "./value";

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description: string;
  actions?: ReactNode;
}) {
  return (
    <header className="page-head">
      <div>
        <p className="eyebrow">Governance workspace</p>
        <h1>{title}</h1>
        <p className="muted">{description}</p>
      </div>
      {actions ? <div className="toolbar">{actions}</div> : null}
    </header>
  );
}

export function Empty({ title, body }: { title: string; body: string }) {
  return (
    <section className="card empty">
      <Icon name="inbox" size={32} />
      <h2>{title}</h2>
      <p>{body}</p>
    </section>
  );
}
