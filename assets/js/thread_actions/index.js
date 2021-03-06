document.addEventListener("DOMContentLoaded", () => {
  if (!document.body.dataset.userId) {
    return;
  }

  const element = document.querySelector(".cf-thread-list");

  if (!element || !element.matches) {
    return;
  }

  import(/* webpackChunkName: "thread_actions" */ "./thread_actions").then(({ default: setupThreadActions }) =>
    setupThreadActions(element)
  );
});
