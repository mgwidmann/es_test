defmodule ESTest.CLI do

  @switches [host: :string, dry_run: :boolean]
  def main(args) do
    {options, _, _} = OptionParser.parse(args, switches: @switches)
    Application.ensure_all_started(:hackney)
    :ok = :hackney_pool.start_pool(__MODULE__, max_connections: 100)
    options[:host]
    |> run(options[:dry_run])
    |> analyze()
    |> report()
  end

  @project Mix.Project.get!().project[:escript][:name]
  def run(nil), do: raise """
  Please provide a host to hit. Usage:
      #{@project} --host dev.weddingwire.com
  """

  @categories ~w(band beauty catering venue ceremonymusic dj dress entertainer rental favor florist invitation jewelry eventproduction officiant partysupplies photography rehearsaldinner transportation travel other videography cake planner)
  @letters ?a..?z
  @partner_key "163r5mm3"
  def run(host, dry_run) do
    for category <- @categories, letter <- @letters do
      Task.async(__MODULE__, :search, [host, dry_run, category, letter])
    end |> Enum.map(&(Task.await(&1, :infinity)))
  end

  def search(host, dry_run, category, letter) do
    url = "https://#{host}/apis/v5/public/#{@partner_key}/vendors/search?category_name=#{category}&vendor_name=#{<<letter>>}"
    IO.puts ["Running against ", IO.ANSI.cyan, url, IO.ANSI.default_color]
    :timer.tc fn ->
      if dry_run do
        Process.sleep(1_000)
        %HTTPoison.Response{status_code: 200, headers: [{"X-Runtime", "1.0"}]}
      else
        HTTPoison.get!(url, [], hackney: [:insecure, {:pool, __MODULE__}], recv_timeout: :infinity, ssl: [{:versions, [:'tlsv1.2']}])
      end
    end
  end

  def analyze(list) when is_list(list), do: Enum.reduce(list, {0.0, 0.0, 0, 0}, &analyze/2)

  def analyze({actual_time_micro, %HTTPoison.Response{status_code: 200, headers: headers}}, state) do
    headers
    |> Enum.find(&match?({"X-Runtime", _}, &1))
    |> analyze(actual_time_micro / 1_000, state)
  end
  def analyze({"X-Runtime", runtime_string}, actual_time, {average, actual_average, count, failed}) do
    runtime = String.to_float(runtime_string)
    count = count + 1
    avg_diff = (runtime - average) / count
    actual_avg_diff = (actual_time - actual_average) / count
    {avg_diff + average, actual_avg_diff + actual_average, count, failed}
  end
  def analyze(_, _, {average, count, failed}) do
    {average, count, failed + 1}
  end

  def report({average, actual_average, requests, failed}) do
    IO.puts ["Total of ",
              IO.ANSI.cyan, inspect(requests), IO.ANSI.default_color,
              " requests (with ",
              IO.ANSI.cyan, inspect(failed), IO.ANSI.default_color,
              " failed) averaging ",
              IO.ANSI.cyan, inspect(average), IO.ANSI.default_color,
              " seconds (actual elapsed average ",
              IO.ANSI.cyan, inspect(actual_average), IO.ANSI.default_color,
              " seconds)"]
  end
end
