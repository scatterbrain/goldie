defmodule NPCTest do
  use ExUnit.Case, async: false
  alias Goldie.NPC
  require Logger
  doctest Goldie.NPC


  setup do
    state = %Goldie.NPC{
      components: [
        Goldie.Component.Mover
    ]}

    {:ok, state: state}
  end

  test "init" do
      assert {:ok, _} = NPC.init(:loc)
  end

  test "handle_info setup", context do
    loc = %{x: 0, y: 0}
    assert {:noreply, state} = NPC.handle_info({:setup, loc}, context.state)
    assert state.entity.nearby == []
  end

  test "terminate", context do
    assert {:noreply, state} = NPC.terminate(:normal, context.state)
  end

  test "setup_components", context do
    assert {:ok, _} = NPC.setup_components(context.state)
  end

  test "teardown_components", context do
    assert {:ok, _} = NPC.teardown_components(context.state)
  end

  test "run_components", context do
    data = %{} 
    assert {:noreply, _} = NPC.handle_info({:event, {:dummy, data}, self()}, context.state)
  end
end


