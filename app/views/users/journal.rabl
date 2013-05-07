node(:journal) do
  {
    shadows: @journal[:shadows],
    errors:  @journal[:errors],
    processed: @journal[:processed]
  }
end