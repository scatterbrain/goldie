defmodule Goldie.Supervisor do
  @moduledoc """
  Root supervisor
  """
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Goldie.LocGrid, [[]]),
      worker(Goldie.Listener, [[]]), 
      supervisor(Goldie.SupervisorNPC, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
