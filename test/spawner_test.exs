defmodule SpawnerTest do
  use ExUnit.Case, async: false
  require Logger
  alias Goldie.Component.Spawner
  doctest Goldie.Component.Spawner

  setup do
    assert {:ok, state} = Spawner.setup(%{ entity: %{id: "myid", pid: self()}})
    on_exit fn ->
      assert {:ok, _state} = Spawner.teardown(state)
    end

    {:ok, state: state}
  end

  test "spawn npc", context do
    state = context.state
    loc = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms() 
    }
    state = put_in(state, [:entity, :loc], loc)
    msg = %{
      fromX: 0.0, 
      fromY: 0.0, 
      toX: 0.0001, 
      toY: 0.0001
    } 
    assert {:ok, {:move, msg}, state} = Spawner.handle_event({:move, msg}, self(), state)
    assert state.entity.last_spawn.loc.x == state.entity.loc.from.x
    assert state.entity.last_spawn.loc.y == state.entity.loc.from.y
    assert_in_delta state.entity.last_spawn.timestamp, Goldie.Utils.timestamp_ms(), 5 #last_spawn has happened within 5ms
  end

  test "spawn npc when last spawn was long ago", context do
    state = context.state
    loc = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms() 
    }
    state = put_in(state, [:entity, :loc], loc)
    last_spawn = %{ timestamp: Goldie.Utils.timestamp_ms() - 60_000, 
      loc: %{x: loc.from.x, y: loc.from.y }}
    state = put_in(state, [:entity, :last_spawn], last_spawn)
    
    msg = %{
      fromX: 0.0, 
      fromY: 0.0, 
      toX: 0.0001, 
      toY: 0.0001
    } 
    assert {:ok, {:move, msg}, state} = Spawner.handle_event({:move, msg}, self(), state)
    assert state.entity.last_spawn.loc.x == state.entity.loc.from.x
    assert state.entity.last_spawn.loc.y == state.entity.loc.from.y
    assert_in_delta state.entity.last_spawn.timestamp, Goldie.Utils.timestamp_ms(), 5 #last_spawn has happened within 5ms
  end

  test "spawn npc when last spawn was far away", context do
    state = context.state
    loc = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms() 
    }
    state = put_in(state, [:entity, :loc], loc)
    last_spawn = %{ timestamp: Goldie.Utils.timestamp_ms(), 
      loc: %{x: loc.from.x + 2000, y: loc.from.y }}
    state = put_in(state, [:entity, :last_spawn], last_spawn)
    
    msg = %{
      fromX: 0.0, 
      fromY: 0.0, 
      toX: 0.0001, 
      toY: 0.0001
    } 
    assert {:ok, {:move, msg}, state} = Spawner.handle_event({:move, msg}, self(), state)
    assert state.entity.last_spawn.loc.x == state.entity.loc.from.x
    assert state.entity.last_spawn.loc.y == state.entity.loc.from.y
    assert_in_delta state.entity.last_spawn.timestamp, Goldie.Utils.timestamp_ms(), 5 #last_spawn has happened within 5ms
  end


  test "fail spawn npc when last spawn was here and now", context do
    state = context.state
    loc = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms() 
    }
    state = put_in(state, [:entity, :loc], loc)
    x_nearby = loc.from.x - 0.001
    y_nearby = loc.from.y - 0.001
    spawn_happened = Goldie.Utils.timestamp_ms()
    last_spawn = %{ timestamp: spawn_happened, 
      loc: %{x: x_nearby, y: y_nearby }}
    state = put_in(state, [:entity, :last_spawn], last_spawn)
    
    msg = %{
      fromX: 0.0, 
      fromY: 0.0, 
      toX: 0.0001, 
      toY: 0.0001
    } 
    assert {:ok, {:move, msg}, state} = Spawner.handle_event({:move, msg}, self(), state)
    #Last spawn location hasn't 
    assert state.entity.last_spawn.loc.x == x_nearby
    assert state.entity.last_spawn.loc.y == y_nearby
    assert state.entity.last_spawn.timestamp == spawn_happened #Spawn timestamp hasn't changed 
  end
end
