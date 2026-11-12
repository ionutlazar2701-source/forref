// UI latch for the second ABANDON tap. The reducer still requires confirmed=true.
// Navigation, Back, page exit, and a changed phase or mode drop the latch.

export function createAbandonArm() {
  let armed = false;
  let context = "";

  return {
    armed() {
      return armed;
    },
    context() {
      return context;
    },
    disarm(reason) {
      const was = armed;
      armed = false;
      context = "";
      return { disarmed: was, reason: reason || "disarm" };
    },
    arm(next) {
      armed = true;
      context = String(next || "");
    },
    retain(next) {
      const wanted = String(next || "");
      if (armed && context !== wanted) {
        return this.disarm("context");
      }
      return { disarmed: false, reason: "same" };
    },
    confirmed(next) {
      const wanted = String(next || "");
      if (armed && context === wanted) {
        this.disarm("confirmed");
        return true;
      }
      return false;
    },
  };
}
