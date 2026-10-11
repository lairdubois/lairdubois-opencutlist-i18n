# Word-level diff of two texts, as [op, text] chunks (op = :same, :del or :ins) : words, runs of
# whitespace and single punctuation marks are the units, so a changed word is shown whole
module WordDiff
  # Beyond this many LCS cells, the texts are shown as replaced whole
  MAX_CELLS = 250_000

  module_function

  def call(old_text, new_text)
    a = tokenize(old_text.to_s)
    b = tokenize(new_text.to_s)
    return merge(a.map { |t| [:same, t] }) if a == b
    return merge([[:del, old_text.to_s], [:ins, new_text.to_s]]) if a.size * b.size > MAX_CELLS

    merge(walk(a, b))
  end

  def tokenize(text)
    text.scan(/\s+|[\p{L}\p{N}_]+|./m)
  end

  # Longest common subsequence table, walked from the start : deletions before insertions
  def walk(a, b)
    lengths = Array.new(a.size + 1) { Array.new(b.size + 1, 0) }
    (a.size - 1).downto(0) do |i|
      (b.size - 1).downto(0) do |j|
        lengths[i][j] = a[i] == b[j] ? lengths[i + 1][j + 1] + 1 : [lengths[i + 1][j], lengths[i][j + 1]].max
      end
    end
    chunks = []
    i = j = 0
    while i < a.size && j < b.size
      if a[i] == b[j]
        chunks << [:same, a[i]]
        i += 1
        j += 1
      elsif lengths[i + 1][j] >= lengths[i][j + 1]
        chunks << [:del, a[i]]
        i += 1
      else
        chunks << [:ins, b[j]]
        j += 1
      end
    end
    chunks.concat(a[i..].map { |t| [:del, t] }, b[j..].map { |t| [:ins, t] })
  end

  # Each run of changes becomes one deletion then one insertion ; a lone space between two
  # changes joins them, so a rewritten phrase reads as one change
  def merge(chunks)
    chunks = chunks.reject { |_, text| text.empty? }
    merged = []
    del = +""
    ins = +""
    flush = lambda do
      merged << [:del, del] unless del.empty?
      merged << [:ins, ins] unless ins.empty?
      del = +""
      ins = +""
    end
    chunks.each_with_index do |(op, text), i|
      if op == :same && text.match?(/\A\s+\z/) && (del + ins).present? && chunks[i + 1] && chunks[i + 1][0] != :same
        op = nil
        del << text
        ins << text
      end
      case op
      when :del then del << text
      when :ins then ins << text
      when :same
        flush.call
        merged.last&.first == :same ? merged.last[1] += text : merged << [:same, text.dup]
      end
    end
    flush.call
    merged
  end
end
