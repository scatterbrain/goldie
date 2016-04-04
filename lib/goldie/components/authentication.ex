defmodule Goldie.Component.Authentication do
  use Goldie.Component
  alias Goldie.Event
  require Logger

  @spec setup(Goldie.Player) :: {:ok, Goldie.Player}  
  def setup(%Goldie.Player { :entity => entity } = state) do
    entity = Map.merge(entity, %{
      id: nil, 
      pid: self()
    })
    {:ok,  %Goldie.Player { state | entity: entity }}
  end

  @spec handle_event(Event.t, pid, struct) :: {:ok|:stop, Event.t, struct}
  def handle_event({:register, msg} = event, _from, %Goldie.Player { :entity => %{ :id => nil } = entity } = state) do
    Logger.debug("Register: #{msg.passwd_hash}")
    id = Goldie.Utils.id(:player)
    name = "Recruit"
    entity = Map.merge(entity, %{
      id: id, 
      asset: "Player",
      password: msg.passwd_hash, 
      name: name
    })

    gc_id = Map.get(entity, :gc_id, "")
    can_change = not Map.get(entity, :name_changed, false)
    reply = %{ id: id, gc_id: gc_id, canChange: can_change, name: name }
    Goldie.Component.SocketHandler.send_socket(Goldie.Message.reply(msg, reply))

    {:ok, event, %Goldie.Player { state | authenticated: true, entity: entity }}
  end

  def handle_event({:auth, msg} = event, _from, %Goldie.Player { :entity => %{ :id => nil } = entity } = state) do
    Logger.debug("Auth: #{msg.id} #{msg.passwd_hash}")
    name = "Recruit"
    entity = Map.merge(entity, %{
      id: msg.id, 
      asset: "Player",
      password: msg.passwd_hash, 
      name: name
    })
    gc_id = Map.get(entity, :gc_id, "")
    can_change = not Map.get(entity, :name_changed, false)
    reply = %{ id: msg.id, gc_id: gc_id, canChange: can_change, name: name }
    Goldie.Component.SocketHandler.send_socket(Goldie.Message.reply(msg, reply))

    {:ok, event, %Goldie.Player { state | authenticated: true, entity: entity }}
  end

  @doc """
  Don't allow other events to progress when the player is not authenticated 
  """
  def handle_event(event, _from, %Goldie.Player { :authenticated => false } = state) do
    {:stop, event, state}
  end

  @doc """
  Event Handler sink
  """
  def handle_event(event, _from, state) do
    {:ok, event, state}
  end

end
