import KeycloakProvider from "next-auth/providers/keycloak";
import { NextAuthOptions } from "next-auth";

interface KeycloakProfile {
  realm_access?: {
    roles: string[]
  }
}

const validRoles = ["admin", "user", "researcher", "moderator"] as const;
type Role = typeof validRoles[number];


export const authOptions: NextAuthOptions = {
  providers: [
    KeycloakProvider({
      clientId: process.env.KEYCLOAK_CLIENT_ID!,
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET!,
      issuer: process.env.KEYCLOAK_ISSUER!,
    }),
  ],
  callbacks: {
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.sub!
        session.user.roles = token.roles as string[]
      }
      return session
    },
    async jwt({ token, account, profile }) {
      if (account && profile) {
        const keycloakProfile = profile as KeycloakProfile
        console.log(keycloakProfile)
        token.roles = keycloakProfile.realm_access?.roles.filter(r => validRoles.includes(r as Role)) || []
      }
      return token
    },
  },
  session: {
    strategy: "jwt",
  },
};
