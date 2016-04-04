defmodule Goldie.SupervisorNPC do
  @moduledoc """
  NPC supervisor
  """
  use Supervisor
  require Logger

  def start_npc(opts) do
    Supervisor.start_child(__MODULE__, opts)
  end

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    children = [
      worker(Goldie.NPC, [], restart: :temporary)      
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

end
