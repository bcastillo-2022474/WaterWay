import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth"; // adjust path to your auth config

export default async function ProtectedPage() {
  const session = await getServerSession(authOptions);

  if (!session) {
    // Redirect if no session
    return (
      <div>
        <h1>Unauthorized</h1>
        <p>Please<a href="/api/auth/signin">sign in</a>.</p>
      </div>
    );
  }

  return (
    <div>
      <h1>Protected Page</h1>
      <p>You are logged in as: {session.user?.name}</p>
      <p>Your roles: {(session.user?.roles || []).join(", ")}</p>
      <pre>{JSON.stringify(session, null, 2)}</pre>
    </div>
  );
}
