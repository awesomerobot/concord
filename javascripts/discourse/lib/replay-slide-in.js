/**
 * Core starts the slide-in channel list's opening slide just before the
 * channels inside it render. On a slow phone that render holds up the frame,
 * and the slide is timed from the frame's start, so by the time the list is
 * first drawn the slide is already over and the list seems to pop in. This
 * starts the slide from when the list is actually drawn.
 *
 * @param {Element} element Something rendered inside the list.
 */
export default function replaySlideIn(element) {
  const panel = element.closest(".menu-panel.slide-in");
  if (!panel) {
    return;
  }

  // Runs before the first frame that has the channels in it.
  requestAnimationFrame(() => {
    // Core's two: one to put the list off screen, then the slide. A slide
    // that's still pending hasn't been drawn at all yet.
    const opening = panel.getAnimations()[1];

    if (opening?.pending) {
      opening.startTime = performance.now();
    }
  });
}
