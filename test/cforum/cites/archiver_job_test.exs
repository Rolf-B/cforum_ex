defmodule Cforum.Cites.ArchiverJobTest do
  use Cforum.DataCase

  alias Cforum.Jobs.CitesArchiverJob
  alias Cforum.Cites
  alias Cforum.Cites.Vote

  test "archive/0 deletes an cite with negative score" do
    cite = insert(:cite, created_at: Timex.now() |> Timex.shift(weeks: -2))
    insert(:cite_vote, cite: cite, vote_type: Vote.downvote())

    CitesArchiverJob.archive()

    assert Cites.list_cites(false) == []
    assert Cites.list_cites(true) == []
  end

  test "archive/0 deletes an cite with score=0" do
    insert(:cite, created_at: Timex.now() |> Timex.shift(weeks: -2))

    CitesArchiverJob.archive()

    assert Cites.list_cites(false) == []
    assert Cites.list_cites(true) == []
  end

  test "archive/0 archives an cite with positive score" do
    cite = insert(:cite, created_at: Timex.now() |> Timex.shift(weeks: -2))
    insert(:cite_vote, cite: cite, vote_type: Vote.upvote())

    CitesArchiverJob.archive()

    assert Cites.list_cites(false) == []
    assert Enum.map(Cites.list_cites(true), & &1.cite_id) == [cite.cite_id]
  end

  test "archive/0 ignores already archived cites" do
    cite = insert(:cite, created_at: Timex.now() |> Timex.shift(weeks: -2), archived: true)
    insert(:cite_vote, cite: cite, vote_type: Vote.downvote())

    CitesArchiverJob.archive()

    assert Cites.list_cites(false) == []
    assert Enum.map(Cites.list_cites(true), & &1.cite_id) == [cite.cite_id]
  end

  test "archive/0 creates a search document for a cite to archive"
end