import { Sidebar } from "@/components/sidebar";
import { currentAdmin } from "@/lib/api";
import { permittedNavigation } from "@/lib/nav";
import { logout } from "../login/actions";
import { WorkspaceHeader } from "@/components/workspace-header";
import { Icon } from "@/components/icon";

export default async function AdminLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const admin = await currentAdmin();
  const groups = permittedNavigation(admin.permissions);
  return (
    <div className="admin-layout">
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <Sidebar groups={groups} />
      <div className="main">
        <WorkspaceHeader groups={groups} email={admin.email} role={admin.role}>
          <form action={logout}>
            <button className="signout-button" title="Sign out">
              <Icon name="logout" size={18} />
              <span className="sr-only">Sign out</span>
            </button>
          </form>
        </WorkspaceHeader>
        <main className="content" id="main-content" tabIndex={-1}>
          {children}
        </main>
      </div>
    </div>
  );
}
