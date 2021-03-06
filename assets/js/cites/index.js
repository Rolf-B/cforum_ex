if (document.body.dataset.controller === "CiteController") {
  const loadVotingJs =
    document.body.dataset.action === "index_voting" ||
    (document.body.dataset.action === "show" && document.body.classList.contains("votable"));

  if (loadVotingJs) {
    import(/* webpackChunkName: "cites" */ "./voting.js");
  }

  if (document.body.dataset.action === "new") {
    import(/* webpackChunkName: "cites" */ "./new-cite.js");
  }
}
