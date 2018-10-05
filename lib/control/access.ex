defmodule Control.Access do
  import Kernel, except: [get_in: 2, update_in: 3, get_and_update_in: 3, pop_in: 2]

  #defdelegate at(idx), to: Access
  #defdelegate elem(idx), to: Access
  defdelegate key(k, default \\ nil), to: Access
  defdelegate key!(k), to: Access

  defdelegate fetch(t, k), to: Access
  defdelegate get(t, k, default \\ nil), to: Access
  defdelegate get_and_update(t, k, f), to: Access
  defdelegate pop(t, k), to: Access

  def fetch!(x, k) do
    case fetch(x, k) do
      {:ok, y} -> y
      :error -> raise(KeyError, key: k, term: x)
    end
  end

  def update(t, k, f) do
    elem(get_and_update(t, k, fn x -> {nil, f.(x)} end), 1)
  end

  def each do &each/3 end
  def each(op, data, next) do all(op, Enum.to_list(data), next) end

  def each(t) do &each(&1, &2, &3, t) end

  def each(:get_and_update = op, data, next, t) do
    {get, update} = all(op, Enum.to_list(data), next)
    {Enum.into(get, t), Enum.into(update, t)}
  end

  def each(op, data, next, t) when op in [:get, :update] do
    all(op, Enum.to_list(data), next)
    |> Enum.into(t)
  end

  def values do &values/3 end
  def values(op, data, next) do all(op, Enum.to_list(data), fn x -> Access.elem(1).(op, x, next) end) end

  def values(t) do &values(&1, &2, &3, t) end

  def values(:get_and_update = op, data, next, t) do
    {get, update} = all(op, Enum.to_list(data), fn x -> Access.elem(1).(op |> IO.inspect(), x, next) |> IO.inspect() end)
    {Enum.into(get, t), Enum.into(update, t)}
  end

  def values(op, data, next, t) when op in [:get, :update] do
    all(op, Enum.to_list(data), fn x -> Access.elem(1).(op, x, next) end)
    |> Enum.into(t)
  end

  def map_as_list do &go_map_as_list/3 end

  def go_map_as_list(:get, data, next) do next.(Enum.to_list(data)) end
  def go_map_as_list(:get_and_update, data, next) do Kernel.update_in(next.(Enum.to_list(data)), [Access.elem(1)], &Map.new/1) end

  def map_values(:get, data, next) do Enum.map(data, next) end

  def get_in(t, [x]) when is_function(x, 3) do x.(:get, t, fn x -> x end) end
  def get_in(t, [x | xs]) when is_function(x, 3) do x.(:get, t, fn t2 -> get_in(t2, xs) end) end
  def get_in(nil, [_]) do nil end
  def get_in(nil, [_ | xs]) do get_in(nil, xs) end
  def get_in(t, [x]) do Access.get(t, x) end
  def get_in(t, [x | xs]) do get_in(Access.get(t, x), xs) end

  def get_and_update_in(t, [x], f) when is_function(x, 3) do x.(:get_and_update, t, f) end
  def get_and_update_in(t, [x | xs], f) when is_function(x, 3) do x.(:get_and_update, t, fn t2 -> get_and_update_in(t2, xs, f) end) end
  def get_and_update_in(t, [x], f) do get_and_update(t, x, f) end
  def get_and_update_in(t, [x | xs], f) do get_and_update(t, x, fn t2 -> get_and_update_in(t2, xs, f) end) end

  def update_in(t, [x], f) when is_function(x, 3) do x.(:update, t, f) end
  def update_in(t, [x | xs], f) when is_function(x, 3) do x.(:update, t, fn t2 -> update_in(t2, xs, f) end) end
  def update_in(t, [x], f) do update(t, x, f) end
  def update_in(t, [x | xs], f) do update(t, x, fn t2 -> update_in(t2, xs, f) end) end

  def pop_in(nil, [x | _]) do Access.pop(nil, x) end
  def pop_in(t, [x]) when is_function(x, 3) do x.(:pop, t) end
  def pop_in(t, [x | xs]) when is_function(x, 3) do x.(:pop, t, fn t2 -> pop_in(t2, xs) end) end
  def pop_in(t, [x]) do pop(t, x) end
  def pop_in(t, [x | xs]) do pop(t, x, fn t2 -> pop_in(t2, xs) end) end

  # Accessors

  def all() do
    &all/3
  end

  def all(op, data, next) when op in [:get, :update] and is_list(data) do
    Enum.map(data, next)
  end

  def all(:get_and_update, data, next) when is_list(data) do
    all(data, next, [], [])
  end

  def all(:pop, data, next) when is_list(data) do
    all(data, next, [], [])
  end

  def all(_op, data, _next) do
    raise "Access.all/0 expected a list, got: #{inspect data}"
  end

  def all([head | rest], next, gets, updates) do
    case next.(head) do
      {get, update} -> all(rest, next, [get | gets], [update | updates])
      :pop -> all(rest, next, [head | gets], updates)
    end
  end

  def all([], _next, gets, updates) do
    {:lists.reverse(gets), :lists.reverse(updates)}
  end

  def at(index) when is_integer(index) and index >= 0 do
    fn op, data, next -> at(op, data, next, index) end
  end

  def at(:get, data, next, index) when is_list(data) do
    data |> Enum.at(index) |> next.()
  end

  def at(:get_and_update, data, next, index) when is_list(data) do
    get_and_update_at(data, index, next, [])
  end

  def at(_op, data, _next, _index) do
    raise "Access.at/1 expected a list, got: #{inspect(data)}"
  end

  def get_and_update_at([head | rest], 0, next, updates) do
    case next.(head) do
      {get, update} -> {get, :lists.reverse([update | updates], rest)}
      :pop -> {head, :lists.reverse(updates, rest)}
    end
  end

  def get_and_update_at([head | rest], index, next, updates) do
    get_and_update_at(rest, index - 1, next, [head | updates])
  end

  def get_and_update_at([], _index, _next, updates) do
    {nil, :lists.reverse(updates)}
end
end
