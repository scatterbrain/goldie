defmodule Goldie.Utils do
  @moduledoc """
  Misc utils
  """

  @doc """
  min of two numbers
  """
  @spec min(number, number) :: number()
  def min(x, y) when x < y, do: x
  def min(_x, y), do: y

  @doc """
  max of two numbers
  """
  @spec max(number, number) :: number()
  def max(x, y) when x > y, do: x
  def max(_x, y), do: y

  @doc """
  Generate an id
  """
  @spec id(atom) :: binary
  def id(prefix) when is_atom(prefix) do
    id(:erlang.atom_to_binary(prefix, :utf8))
  end
  
  @spec id(binary) :: binary
  def id(prefix) do
    id = id()
    <<prefix :: binary, ":", id :: binary>>
  end

  @spec id() :: binary
  def id() do
    stamp = :erlang.phash2({:erlang.node(), :erlang.monotonic_time()}) 
    :base64.encode(<<stamp :: size(32)>>)
  end

  @doc """
  Convert map string keys to atoms
  """
  def atomify_map_keys(input) when is_map(input) do
    Enum.reduce(input, %{}, fn({key, value}, acc) ->
      Dict.put(acc, String.to_atom(key), atomify_map_keys(value))
    end)
  end
  def atomify_map_keys(input), do: input

  @doc """
  Convert atom keys and values to binary
  """
  def binarify_map(input) when is_map(input) do
    Enum.reduce(input, %{}, fn({key, value}, acc) ->
      Dict.put(acc, binarify_map(key), binarify_map(value))
    end)
  end
  def binarify_map(input) when is_list(input) do
    for elem <- input, do: binarify_map(elem)
  end
  def binarify_map(input) when is_atom(input) and input != true and input != false do 
    :erlang.atom_to_binary(input, :utf8)
  end
  def binarify_map(input), do: input

  @spec timestamp_ms() :: integer
  def timestamp_ms() do
    {mega, seconds, ms} = :os.timestamp()
    (mega*1000000 + seconds)*1000 + :erlang.round(ms/1000)
  end

  @doc """
  How many milliseconds since a millisecond timestamp
  """
  @spec ms_since_timestamp_ms(integer) :: integer
  def ms_since_timestamp_ms(ts) do
    timestamp_ms() - ts
  end

  @doc """
  Current time in seconds since 1.1.1970 in universal time
  """
  @spec timestamp_epoch() :: integer
  def timestamp_epoch() do
    seconds = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
    unix_start_epoch={{1970,1,1},{0,0,0}}
    unix_start_epoch_sec = :calendar.datetime_to_gregorian_seconds(unix_start_epoch)
    seconds - unix_start_epoch_sec
  end

  @doc """
  Entity contact information 
  """
  @spec entity_contact(struct) :: struct
  def entity_contact(entity) do
    Map.take(entity, [
      :id, 
      :pid, 
      :loc, 
      :asset
    ])
  end

  @doc """
  Make an union of two lists of entities
  """
  @spec entity_union(list, list) :: list
  def entity_union(list1, list2) do
    Enum.reduce(list1, list2, fn(entity, acc_in) -> 
      case select_matches(acc_in, %{id: entity.id}) do
        [] ->
          [entity|acc_in]
        _ ->
          acc_in
      end
    end) 
  end

  @doc """
  Select maps from a list maps that match given keys 
  Example: select_matches([%{id: 1, other: "data1"}, %{id: 2, other: "data2"}], %{id: 1, other: "data1"}) -> [%{id: 1}]
  """
  @spec select_matches([map], map) :: [map]
  def select_matches(map_list, match_map) do
    select_or_delete_matches(map_list, match_map, :select)
  end

  @doc """
  Delete props from a list that match certain props.
  """
  @spec delete_matches([map], map) :: [map]
  def delete_matches(map_list, match_map) do
    select_or_delete_matches(map_list, match_map, :delete)
  end

  ## Internal functions

  ## Select or delete props from a list of props.
  @spec select_or_delete_matches([map], map, :select | :delete) :: [map]
  defp select_or_delete_matches(map_list, match_map, operation) do
    Enum.filter(map_list, fn(map) ->
      case match(map, match_map) do
        true ->
          operation == :select
        _ ->
          operation != :select
      end
    end)
  end

  ##Test if a props matches another props.
  @spec match(map, map) :: boolean
  defp match(map, match_map) do
    Enum.reduce(Map.to_list(match_map), true, fn({match_key, match_val}, acc_in) ->
      case acc_in do
        false -> ## Found out already that not a match
          false
          _ ->
            case Map.get(map, match_key) do
              nil ->
                false;
              map_val when is_map(map_val) ->
            match(map_val, match_val)
              ^match_val ->
                true
              _ ->
                false
            end
        end
    end)  
  end
end
