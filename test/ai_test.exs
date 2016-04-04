defmodule AITest do
  use ExUnit.Case, async: false
  require Logger
  alias Goldie.Component.AI
  doctest Goldie.Component.AI

  setup do
    assert {:ok, state} = AI.setup(%{ timers: %{}, entity: %{id: "myid", pid: self()}})
    on_exit fn ->
      assert {:ok, _state} = AI.teardown(state)
    end

    {:ok, state: state}
  end

  test "start movement timer", context do
    state = context.state
    loc = Goldie.Location.new(0.0001, 0.0001, 0.0002, 0.0002)
    state = put_in(state, [:entity, :loc], loc)
    msg = %{
    } 
    assert {:ok, {:move, msg}, state} = AI.handle_event({:move, msg}, self(), state)
  end

  test "do movement", context do
    state = context.state
    loc = Goldie.Location.new(1.0, 1.0, 2.0, 2.0)
    #Act like the last loc update has happened in 30 seconds ago
    #Meaning that the AI mover should already be in it's loc.to.x/y
    loc = Map.put(loc, :updated, loc.updated - 30_000)     
    state = put_in(state, [:entity, :loc], loc)
    msg = %{
    } 
    assert {:ok, {:new_move, msg}, state} = AI.handle_event({:new_move, msg}, self(), state)
    #AI should send a new move command
    assert_receive {:event, {:move, msg}, _}
    #Assert that the AI asks for movement from it's to position since it has had
    #30 seconds to move there
    assert msg.fromX == loc.to.x
    assert msg.fromY == loc.to.y
  end

end
