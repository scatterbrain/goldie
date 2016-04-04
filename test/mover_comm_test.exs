defmodule MoverCommTest do
  use ExUnit.Case, async: false
  require Logger
  alias Goldie.Component.MoverComm
  doctest Goldie.Component.MoverComm

  setup do
    assert {:ok, state} = MoverComm.setup(%{ entity: %{id: "myid", pid: self()}})
    state = Map.put(state, :authenticated, true)
    on_exit fn ->
      assert {:ok, _state} = MoverComm.teardown(state)
    end

    {:ok, state: state}
  end

  test "move and inform nearby", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    msg = %{
      entity: other_entity, 
      move_type: :moved, 
      move_start: true
    } 
    assert {:ok, {:moved, _}, _state} = MoverComm.handle_event({:moved, msg}, self(), state)
    assert_receive {:event, {:socket_send, %{_cmd: :gomodify, id: "otherid"} = msg}, _}
  end

  test "appeared and goadd nearby", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{
      id: "otherid", 
      pid: self(), 
      loc: other_location, 
      asset: "Player"
    }
    msg = %{
      entity: other_entity, 
      move_type: :appeared, 
      move_start: true
    }
    assert {:ok, {:moved, _}, _state} = MoverComm.handle_event({:moved, msg}, self(), state)
    assert_receive {:event, {:socket_send, %{_cmd: :gomodify, id: "otherid"} = msg}, _}
  end

  test "disappeared and remove nearby", context do
    state = context.state
    other_entity = %{id: "otherid", pid: self()}
    msg = %{
      entity: other_entity, 
      move_type: :disappeared, 
      move_start: false
    }
    state = put_in(state, [:entity, :added_entity_ids], [other_entity.id])
    assert {:ok, {:moved, _}, state} = MoverComm.handle_event({:moved, msg}, self(), state)
    assert state.entity.added_entity_ids == []
    assert_receive {:event, {:socket_send, %{_cmd: :goremove, id: "otherid"} = msg}, _}
  end

  test "removed msg", context do
    state = context.state
    other_entity = %{id: "otherid", pid: self()}
    msg = %{
      entity: other_entity
    }
    state = put_in(state, [:entity, :added_entity_ids], [other_entity.id])
    assert {:ok, {:removed, _}, state} = MoverComm.handle_event({:removed, msg}, self(), state)
    assert state.entity.added_entity_ids == []
    assert_receive {:event, {:socket_send, %{_cmd: :goremove, id: "otherid"} = msg}, _}
  end

  test "intro msg", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{
      id: "otherid", 
      pid: self(), 
      loc: other_location, 
      asset: "Player"
    
    }
    msg = %{
      entity: other_entity
    }
    state = put_in(state, [:entity, :added_entity_ids], [])
    assert {:ok, {:intro, _}, _state} = MoverComm.handle_event({:intro, msg}, self(), state)
    assert_receive {:event, {:socket_send, %{_cmd: :gomodify, id: "otherid"} = msg}, _}
  end
end
