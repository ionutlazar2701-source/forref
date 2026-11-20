// Applies one already-authorized control intent. Phase rules stay in Match Clock.

export function applyAuthorizedIntent(intent, arm, context, perform) {
  if (intent !== "ABANDON_GAME") {
    arm.disarm("other-intent");
  }
  const confirmed = intent === "ABANDON_GAME" && arm.confirmed(context);
  const result = perform(intent, { confirmed: confirmed });
  if (result && result.reason === "CONFIRM_REQUIRED") {
    arm.arm(context);
    return { state: "confirm", result: result };
  }
  arm.disarm("resolved");
  if (result && result.ok) {
    return { state: "applied", result: result };
  }
  return { state: "rejected", result: result || { ok: false, reason: "NOT_APPLIED" } };
}
