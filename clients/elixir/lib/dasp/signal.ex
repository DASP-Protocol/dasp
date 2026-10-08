defmodule DASP.Signal do
  @moduledoc "Core message module lookup. All constructors return ordinary Jido.Signal values."
  def module("dasp.v1.session.open"), do: DASP.Signal.SessionOpen
  def module("dasp.v1.session.opened"), do: DASP.Signal.SessionOpened
  def module("dasp.v1.command"), do: DASP.Signal.Command
  def module("dasp.v1.receipt"), do: DASP.Signal.Receipt
  def module("dasp.v1.update"), do: DASP.Signal.Update
  def module("dasp.v1.progress"), do: DASP.Signal.Progress
  def module("dasp.v1.view.read"), do: DASP.Signal.ViewRead
  def module("dasp.v1.view"), do: DASP.Signal.View
  def module("dasp.v1.updates.read"), do: DASP.Signal.UpdatesRead
  def module("dasp.v1.updates"), do: DASP.Signal.Updates
  def module("dasp.v1.outcome.read"), do: DASP.Signal.OutcomeRead
  def module("dasp.v1.outcome"), do: DASP.Signal.Outcome
  def module("dasp.v1.resync.required"), do: DASP.Signal.ResyncRequired
  def module("dasp.v1.failure"), do: DASP.Signal.Failure
  def module(_), do: nil

  @doc "Return the expected reply type for a core request, or nil for other types."
  def reply_type("dasp.v1.session.open"), do: "dasp.v1.session.opened"
  def reply_type("dasp.v1.command"), do: "dasp.v1.receipt"
  def reply_type("dasp.v1.view.read"), do: "dasp.v1.view"
  def reply_type("dasp.v1.updates.read"), do: "dasp.v1.updates"
  def reply_type("dasp.v1.outcome.read"), do: "dasp.v1.outcome"
  def reply_type(_), do: nil
end
