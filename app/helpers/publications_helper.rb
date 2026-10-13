module PublicationsHelper
  MAX_LINES = 2000

  FileDiff = Struct.new(:path, :lines, :additions, :deletions, keyword_init: true)

  # A unified patch split by file : lines from the first hunk on, headers left out
  def file_diffs(patch)
    patch.split(/^(?=diff --git )/).filter_map do |chunk|
      lines = chunk.lines(chomp: true)
      path = lines.first.to_s[%r{ b/(.+)\z}, 1] or next
      body = lines.drop_while { |l| !l.start_with?("@@") }
      FileDiff.new(path: path, lines: body,
                   additions: body.count { |l| l.start_with?("+") }, deletions: body.count { |l| l.start_with?("-") })
    end
  end

  # The diff's lines, each as [line, content] : a removed block followed by an added one gets its changed words marked
  def diff_rows(lines)
    rows = []
    i = 0
    while i < lines.size
      dels = lines[i..].take_while { |l| l.start_with?("-") }
      adds = lines[(i + dels.size)..].take_while { |l| l.start_with?("+") }
      if dels.any? && adds.any?
        old_html, new_html = word_marked_lines(dels, adds)
        rows.concat(dels.zip(old_html), adds.zip(new_html))
        i += dels.size + adds.size
      else
        rows << [lines[i], lines[i][1..]]
        i += 1
      end
    end
    rows
  end

  def diff_line_class(line)
    case line[0]
    when "+" then "bg-green-50 text-green-900"
    when "-" then "bg-red-50 text-red-900"
    when "@" then "bg-sky-50 text-sky-800"
    when "\\" then "text-stone-400"
    else "text-stone-600"
    end
  end

  private

  # Both blocks diffed as a whole, then cut back into lines. Left unmarked when they share no word.
  def word_marked_lines(dels, adds)
    old_lines = dels.map { |l| l[1..] }
    new_lines = adds.map { |l| l[1..] }
    chunks = WordDiff.call(old_lines.join("\n"), new_lines.join("\n"))
    return [old_lines, new_lines] unless chunks.any? { |op, text| op == :same && text.match?(/\S/) }

    [side_lines(chunks, :del, "rounded-sm bg-red-200"), side_lines(chunks, :ins, "rounded-sm bg-emerald-200 no-underline")]
  end

  def side_lines(chunks, op, mark_class)
    lines = [[]]
    chunks.each do |chunk_op, text|
      next unless chunk_op == :same || chunk_op == op

      text.split("\n", -1).each_with_index do |part, n|
        lines << [] if n.positive?
        next if part.empty?

        lines.last << (chunk_op == :same ? part : tag.public_send(op, diff_whitespace(part), class: mark_class))
      end
    end
    lines.map { |parts| safe_join(parts) }
  end
end
