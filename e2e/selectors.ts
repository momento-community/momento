/**
 * Single source of truth for Playwright selectors against the Flutter web
 * build. Most are text-based since Flutter renders predictable text into the
 * DOM. Where text is ambiguous, we'll add `Semantics(label: ...)` wrappers in
 * the Flutter widget tree and target via `getByLabel`.
 */

export const wordmark = "MOMENTŌ";

export const splash = {
  tagline: /Find what's happening around you/,
  domainText: "momento.community",
};

export const onboarding = {
  taglineFirst: "AROUND YOU",
  titleFirst: "Discover Momentos near you",
  next: "Next",
  skip: "Skip",
  getStarted: "Get started",
};

export const auth = {
  heading: "Get started",
  google: "Continue with Google",
  apple: "Continue with Apple",
  email: "Continue with email",
  signInTab: "Sign in",
  signUpTab: "Sign up",
  emailHint: "Email",
  passwordHint: "Password",
  termsBlurb: /By continuing, you agree to our Terms of Service/,
};

export const discover = {
  filterTooltip: "Filter",
};

export const profile = {
  logout: "Logout",
  editProfile: "Edit Profile",
  freemiumHeading: "Free Momentos",
  seedDevButton: "Seed dev Momentos",
};

export const create = {
  heading: "Create a Momentō",
  publish: /^Publish Momentō$|^Pay & Publish/,
  freemiumQuotaToast: "Coming soon — paid Momentos launch later",
  successToast: "Momentō published",
};

export const filter = {
  sheetTitle: "Filter Momentos",
  reset: "Reset",
  apply: "Apply Filters",
};
