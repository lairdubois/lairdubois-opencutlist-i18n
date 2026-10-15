module ApplicationHelper
  # Status dot classes, shared by the search bar filters and the translator's editor badges
  STATUS_DOTS = {
    "not_translated" => "bg-yellow-400",
    "outdated" => "bg-orange-500",
    "not_approved" => "bg-sky-500",
    "approved" => "bg-emerald-500"
  }.freeze

  # Why a translation is to review : the fr changed, or an open issue contests it
  def to_review_label(translation)
    translation.outdated? ? t("status.outdated") : t("status.contested")
  end

  # Languages page cards, by progress : some outdated, some left to translate, all translated, all approved
  LANGUAGE_CARDS = {
    outdated: "border-orange-300 bg-orange-50 hover:border-orange-500",
    translating: "border-stone-200 bg-white hover:border-stone-400",
    translated: "border-sky-300 bg-sky-50 hover:border-sky-500",
    approved: "border-emerald-300 bg-emerald-50 hover:border-emerald-500"
  }.freeze

  # Header sections, by the controllers their pages belong to
  NAV_SECTIONS = {
    keys: %w[units comments branches],
    translate: %w[languages translations reference_languages issues],
    sync: %w[syncs],
    import: %w[imports],
    pretranslations: %w[pretranslations],
    users: %w[users volunteers],
    migration: %w[migrations],
    publish: %w[publications github_accounts],
    help: %w[help help_requests]
  }.freeze

  # Header link, underlined (tab-like, on the header's bottom edge) when the current page is in its section.
  # badge : a count shown after the label when positive
  def nav_link(section, path, badge: nil, title: nil)
    active = NAV_SECTIONS[section].include?(controller_name)
    link_to path, aria: { current: ("page" if active) }, title: title,
            class: ["flex h-full items-center gap-1.5 border-b-2 pt-0.5",
                    active ? "border-stone-800 font-medium text-stone-900" : "border-transparent text-stone-600 hover:text-stone-900"] do
      safe_join([t("layouts.application.#{section}"), nav_badge(badge)])
    end
  end

  # The admin sections, grouped in the header's dropdown (admin_menu_link)
  ADMIN_MENU = %i[sync import pretranslations users migration publish].freeze

  def nav_badge(badge)
    tag.span(badge, class: "rounded-full bg-sky-600 px-1.5 text-xs leading-4 font-medium text-white tabular-nums") if badge.to_i.positive?
  end

  # A row of the admin dropdown, highlighted when the current page is in its section
  def admin_menu_link(section, path, badge: nil, title: nil)
    active = NAV_SECTIONS[section].include?(controller_name)
    link_to path, aria: { current: ("page" if active) }, title: title,
            class: ["flex items-center justify-between gap-3 rounded px-3 py-1.5",
                    active ? "bg-stone-100 font-medium text-stone-900" : "text-stone-700 hover:bg-stone-100"] do
      safe_join([t("layouts.application.#{section}"), nav_badge(badge)])
    end
  end

  # Progress percentage, floored : 100 % only when nothing is left to do
  def progress_percent(done, total)
    number_to_percentage(total.zero? ? 100 : done * 100 / total, precision: 0)
  end

  def status_dot(status, extra = nil)
    tag.span(class: ["h-2 w-2 shrink-0 rounded-full", STATUS_DOTS[status], extra])
  end

  # The $t() refs of a text view (Unit.refs), as i18n-text's refs value : key => { title, url }.
  # url : the page's ref_url (Mod-click opens it in a new tab), the title's hint telling so
  def refs_json(refs)
    refs.to_h do |key, ref|
      url = ref_url(ref)
      [key, { title: [ref.text, (t("refs.open_hint") if url)].compact.join("\n"), url: url }.compact]
    end.to_json
  end

  # A collapsible section's state, as the user left it (collapsible controller's cookie)
  def section_open?(name, default:)
    state = cookies["section_#{name}"]
    state ? state == "open" : default
  end

  # Disclosure caret (heroicons chevron-right), in its button's color ; `extra` gives its rotation when open, spelled out for Tailwind
  def chevron_icon(extra = nil)
    tag.svg(tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "m8.25 4.5 7.5 7.5-7.5 7.5"),
            viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 2.5, aria: { hidden: true },
            class: ["h-3 w-3 shrink-0 transition-transform", extra])
  end

  # Machine suggestions' mark (Remix Icon robot-2-line, Apache 2.0), sized to the text, in its color
  ROBOT_PATH = "M13.5 2C13.5 2.44425 13.3069 2.84339 13 3.11805V5H18C19.6569 5 21 6.34315 21 8V18C21 19.6569 19.6569 21 18 21H6C4.34315 21 3 19.6569 3 18V8C3 6.34315 4.34315 5 6 5H11V3.11805C10.6931 2.84339 10.5 2.44425 10.5 2C10.5 1.17157 11.1716 0.5 12 0.5C12.8284 0.5 13.5 1.17157 13.5 2ZM6 7C5.44772 7 5 7.44772 5 8V18C5 18.5523 5.44772 19 6 19H18C18.5523 19 19 18.5523 19 18V8C19 7.44772 18.5523 7 18 7H13H11H6ZM2 10H0V16H2V10ZM22 10H24V16H22V10ZM9 14.5C9.82843 14.5 10.5 13.8284 10.5 13C10.5 12.1716 9.82843 11.5 9 11.5C8.17157 11.5 7.5 12.1716 7.5 13C7.5 13.8284 8.17157 14.5 9 14.5ZM15 14.5C15.8284 14.5 16.5 13.8284 16.5 13C16.5 12.1716 15.8284 11.5 15 11.5C14.1716 11.5 13.5 12.1716 13.5 13C13.5 13.8284 14.1716 14.5 15 14.5Z".freeze

  def robot_icon(extra = nil)
    tag.svg(tag.path(d: ROBOT_PATH), viewBox: "0 0 24 24", fill: "currentColor", aria: { hidden: true },
            class: ["inline-block h-[1.2em] w-[1.2em] shrink-0 align-[-0.25em]", extra])
  end

  # Marks of the whitespace inside a change, which would be invisible otherwise
  DIFF_WHITESPACE = { " " => "·", "\u00A0" => "⍽", "\t" => "→", "\n" => "↵\n" }.freeze

  # WordDiff chunks : deletions struck in red, insertions in green, their whitespace marked
  def word_diff_tag(chunks)
    safe_join(chunks.map do |op, text|
      case op
      when :del then tag.del(diff_whitespace(text), class: "rounded-sm bg-red-100 text-red-800")
      when :ins then tag.ins(diff_whitespace(text), class: "rounded-sm bg-emerald-100 text-emerald-900 no-underline")
      else text
      end
    end)
  end

  def diff_whitespace(text)
    safe_join(text.split(/([ \u00A0\t\n])/).map do |part|
      (mark = DIFF_WHITESPACE[part]) ? tag.span(mark, class: "opacity-50") : part
    end)
  end
end
