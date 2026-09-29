defmodule PiperComparativeBench do
  @iterations 3_000_000
  @repeats 9
  @input_count 1024

  @expected2 26_756_370_240
  @expected3 324_207_267_022_400
  @expected4 -324_207_267_022_400

  def double_fn(x), do: x * 2

  def add_one_fn(x), do: x + 1

  def square_fn(x), do: x * x

  def negate_fn(x), do: -x

  def build_inputs do
    0..(@input_count - 1)
    |> Enum.map(fn i ->
      rem(i * 17 + 31, 10_000)
    end)
    |> List.to_tuple()
  end

  # --------------------------------------------------------------------------
  # Direct
  # --------------------------------------------------------------------------

  def direct2(inputs) do
    direct2_loop(inputs, 0, 0)
  end

  defp direct2_loop(_inputs, i, total)
       when i == @iterations do
    total
  end

  defp direct2_loop(inputs, i, total) do
    x =
      elem(
        inputs,
        :erlang.band(i, @input_count - 1)
      )

    direct2_loop(
      inputs,
      i + 1,
      total +
        add_one_fn(
          double_fn(x)
        )
    )
  end

  def direct3(inputs) do
    direct3_loop(inputs, 0, 0)
  end

  defp direct3_loop(_inputs, i, total)
       when i == @iterations do
    total
  end

  defp direct3_loop(inputs, i, total) do
    x =
      elem(
        inputs,
        :erlang.band(i, @input_count - 1)
      )

    direct3_loop(
      inputs,
      i + 1,
      total +
        square_fn(
          add_one_fn(
            double_fn(x)
          )
        )
    )
  end

  def direct4(inputs) do
    direct4_loop(inputs, 0, 0)
  end

  defp direct4_loop(_inputs, i, total)
       when i == @iterations do
    total
  end

  defp direct4_loop(inputs, i, total) do
    x =
      elem(
        inputs,
        :erlang.band(i, @input_count - 1)
      )

    direct4_loop(
      inputs,
      i + 1,
      total +
        negate_fn(
          square_fn(
            add_one_fn(
              double_fn(x)
            )
          )
        )
    )
  end

  # --------------------------------------------------------------------------
  # Pipe
  # --------------------------------------------------------------------------

  def pipe2(inputs) do
    pipe2_loop(inputs, 0, 0)
  end

  defp pipe2_loop(_inputs, i, total)
       when i == @iterations do
    total
  end

  defp pipe2_loop(inputs, i, total) do
    x =
      elem(
        inputs,
        :erlang.band(i, @input_count - 1)
      )

    value =
      x
      |> double_fn()
      |> add_one_fn()

    pipe2_loop(
      inputs,
      i + 1,
      total + value
    )
  end

  def pipe3(inputs) do
    pipe3_loop(inputs, 0, 0)
  end

  defp pipe3_loop(_inputs, i, total)
       when i == @iterations do
    total
  end

  defp pipe3_loop(inputs, i, total) do
    x =
      elem(
        inputs,
        :erlang.band(i, @input_count - 1)
      )

    value =
      x
      |> double_fn()
      |> add_one_fn()
      |> square_fn()

    pipe3_loop(
      inputs,
      i + 1,
      total + value
    )
  end

  def pipe4(inputs) do
    pipe4_loop(inputs, 0, 0)
  end

  defp pipe4_loop(_inputs, i, total)
       when i == @iterations do
    total
  end

  defp pipe4_loop(inputs, i, total) do
    x =
      elem(
        inputs,
        :erlang.band(i, @input_count - 1)
      )

    value =
      x
      |> double_fn()
      |> add_one_fn()
      |> square_fn()
      |> negate_fn()

    pipe4_loop(
      inputs,
      i + 1,
      total + value
    )
  end

  # --------------------------------------------------------------------------
  # Composition
  # --------------------------------------------------------------------------

  def compose2(f, g) do
    fn x ->
      g.(f.(x))
    end
  end

  def compose3(f, g, h) do
    fn x ->
      h.(g.(f.(x)))
    end
  end

  def compose4(f, g, h, i) do
    fn x ->
      i.(h.(g.(f.(x))))
    end
  end

  def compose_run(inputs, pipeline) do
    compose_loop(
      inputs,
      pipeline,
      0,
      0
    )
  end

  defp compose_loop(_inputs, _pipeline, i, total)
       when i == @iterations do
    total
  end

  defp compose_loop(inputs, pipeline, i, total) do
    x =
      elem(
        inputs,
        :erlang.band(i, @input_count - 1)
      )

    compose_loop(
      inputs,
      pipeline,
      i + 1,
      total + pipeline.(x)
    )
  end

  # --------------------------------------------------------------------------
  # Measurement
  # --------------------------------------------------------------------------

  def measure(name, fun) do
    _ = fun.()

    Enum.each(
      1..3,
      fn _ ->
        _ = fun.()
      end
    )

    samples =
      Enum.map(
        1..@repeats,
        fn _ ->
          started =
            System.monotonic_time(
              :nanosecond
            )

          result =
            fun.()

          finished =
            System.monotonic_time(
              :nanosecond
            )

          {
            finished - started,
            result
          }
        end
      )

    times =
      Enum.map(
        samples,
        &elem(&1, 0)
      )
      |> Enum.sort()

    median_ns =
      Enum.at(
        times,
        div(@repeats, 2)
      )

    checksum =
      elem(
        List.last(samples),
        1
      )

    ns_per_op =
      median_ns /
      @iterations

    IO.puts(
      "RESULT,Elixir,#{name}," <>
        "#{Float.round(ns_per_op, 6)}," <>
        "#{checksum}"
    )
  end

  # --------------------------------------------------------------------------
  # Main
  # --------------------------------------------------------------------------

  def run do
    inputs =
      build_inputs()

    pipeline2 =
      compose2(
        &double_fn/1,
        &add_one_fn/1
      )

    pipeline3 =
      compose3(
        &double_fn/1,
        &add_one_fn/1,
        &square_fn/1
      )

    pipeline4 =
      compose4(
        &double_fn/1,
        &add_one_fn/1,
        &square_fn/1,
        &negate_fn/1
      )

    if direct2(inputs) != @expected2 do
      raise "direct2 checksum mismatch"
    end

    if direct3(inputs) != @expected3 do
      raise "direct3 checksum mismatch"
    end

    if direct4(inputs) != @expected4 do
      raise "direct4 checksum mismatch"
    end

    if compose_run(inputs, pipeline2) != @expected2 do
      raise "compose2 checksum mismatch"
    end

    if compose_run(inputs, pipeline3) != @expected3 do
      raise "compose3 checksum mismatch"
    end

    if compose_run(inputs, pipeline4) != @expected4 do
      raise "compose4 checksum mismatch"
    end

    measure(
      "direct2",
      fn -> direct2(inputs) end
    )

    measure(
      "pipe2",
      fn -> pipe2(inputs) end
    )

    measure(
      "compose2",
      fn ->
        compose_run(
          inputs,
          pipeline2
        )
      end
    )

    measure(
      "direct3",
      fn -> direct3(inputs) end
    )

    measure(
      "pipe3",
      fn -> pipe3(inputs) end
    )

    measure(
      "compose3",
      fn ->
        compose_run(
          inputs,
          pipeline3
        )
      end
    )

    measure(
      "direct4",
      fn -> direct4(inputs) end
    )

    measure(
      "pipe4",
      fn -> pipe4(inputs) end
    )

    measure(
      "compose4",
      fn ->
        compose_run(
          inputs,
          pipeline4
        )
      end
    )
  end
end


IO.puts(
  "VERSION,Elixir,#{System.version()}"
)

PiperComparativeBench.run()
