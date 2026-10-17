# CLAUDE.md

Guidance for Claude Code in this repository. Setup, configuration and the sync model are in `README.md`.

## What This Is

In-house translation platform replacing Transifex for **OpenCutList** (SketchUp extension, repo
`~/DevProjects/lairdubois-opencutlist-sketchup-extension`, i18n sources in
`src/ladb_opencutlist/yaml/i18n-src/*.yml`, `fr.yml` = source language, `en.yml` = fallback).
Goal : reshape the fr source (rename / move keys, edit texts) without invalidating translators' work.
Weblate was evaluated and rejected.

## Environment

- Rails 8.1 + SQLite (WAL), Tailwind (tailwindcss-rails), Turbo + importmap, Ruby 4.0 from Homebrew :
  prefix commands with `PATH=/opt/homebrew/opt/ruby/bin:$PATH`.
- Dev server on port **3007** : `set -a; source .env; set +a; bin/rails server -p 3007`. It doesn't rebuild
  Tailwind : new classes need `bin/dev` or `bin/rails tailwindcss:watch` (or `:build`). `app/assets/builds/` is generated.
- CodeMirror is vendored in `vendor/javascript` as jsDelivr minified builds (`dist/index.min.js`) :
  `bin/importmap pin` / `update` / `pristine` download unminified files, re-fetch the `.min.js` after.
- `.env` (git-ignored) holds `TRANSIFEX_TOKEN` (secret : never print it, `source .env` without echoing)
  and `TRANSIFEX_RESOURCE=v6`.
- CI (`.github/workflows/ci.yml`, on push to main) runs `bin/rubocop`, `bin/brakeman --no-pager`, `bin/bundler-audit`
  and `bin/importmap audit` : run `bin/rubocop` (`-a` fixes) and `bin/brakeman` after changing Ruby code. Style is
  rubocop-rails-omakase without `Layout/SpaceInsideArrayLiteralBrackets` (`[a, b]`). Brakeman skips `storage/`
  (`config/brakeman.yml`, the OCL checkout) ; a vetted false positive goes into `config/brakeman.ignore` with a `note`.
- Without `OCL_REPO_URL` the app points to the real GitHub repo : don't click / call "Publier" while testing.
- Not deployed yet : target is the user's Debian 12 server next to L'Air du Bois, behind its NGINX,
  at `localize.opencutlist.org`, systemd + rbenv, no Docker (`deploy/`).

## Hard rules

- **No e-mail to translators** for now : `perform_deliveries` stays off unless `OCL_MAIL_ENABLED=1`.
  Never enable it without asking. Dev shows the login link on the login page.
- Don't apply the Transifex import, publish, push or deploy without an explicit request.

## Core design

- `Unit` id is stable, `key` is a mutable attribute : translations, revisions, comments and suggestions follow
  renames. Archive instead of delete (`archived_at`, partial unique index on key).
- Outdated = `Translation.source_hash != Unit.source_hash`. A minor fr edit moves the translations' hash along,
  a major one leaves them outdated (`UnitOperations#edit_source`).
- `Revision` is the append-only history. All admin mutations go through `UnitOperations` / `TranslationOperations`.
- i18next nesting `$t(key)` (~197 in fr) is rewritten on leaf and branch renames (`UnitOperations#rewrite_references`).
- `Baseline` = repo fr.yml as last reconciled, keyed to unit ids. `SourceSync` diffs repo vs baseline (three-way) ;
  `Baseline.record!` keeps the previous unit id per repo key (archived units included) so pending tool renames /
  deletions survive a sync. YAML comments (`Unit#note`, edited on the key page) are three-way synced too ;
  baselines without `"note"` fall back to the tool's.
- Branch comments : `BranchNote(path, note)`, read / written by `I18nYaml::Reader#branch_notes` / `Writer`, three-way
  synced through `Baseline#branch_notes` (nil = recorded before : none), moved by `rename_branch`, edited on the keys
  list's branch rows (no revision). A `@no-translate` line in a key's or branch's note takes the keys out of the
  translators' work, `@translate` puts one back, the closest wins : denormalized as `Unit#translatable`
  (`Unit.refresh_translatable!`, called by every `UnitOperations` touching keys or notes). Translations are kept and
  exported ; excluded from the translator's list, saves, progress ; admins see them with the `notranslate=1` filter.
  A fr source that is a `$t()` or a `{{ var }}` alone (`Unit::COPIED_SOURCE`) is `Unit#copied` (same refresh, also
  called by `edit_source`) : not translatable, wins over `@no-translate` but not over the key's own `@translate` ;
  `YamlExport` writes the source in every language, its translations are kept but ignored (no status, no warnings,
  read-only editor). `notranslate=directive` / `copied` narrow the filter to one kind.
- Rename detection : same fr text, disambiguated by key similarity (trailing segments ×100 + leading) ; ambiguous
  pairs are skipped.
- `Publisher` refuses while the repo fr.yml has unsynced changes ; rewrites quoted key literals in js / twig / ruby and
  warns on leftover dynamic uses. Previewed first (`Publisher#preview`, `OclRepo#preview` : same staging, `git diff --cached`,
  no commit) ; publishing posts the patch's digest and `OclRepo::Stale` refuses it when the changes moved since.
  `OclRepo` = shallow checkout in `storage/ocl_repo`, force-pushed i18n branch.
  `GithubAuth` : the publishing admin's GitHub App user access token when connected (`GithubOauth`, encrypted on
  `User`, refreshed under a row lock), else App installation tokens (`<app>[bot]`), else `OCL_GITHUB_TOKEN` ; passed
  via `http.extraHeader` only, credential helpers and prompts disabled, no push without credentials.
- Base branch (synced with, published from, PR base) = `Setting["base_branch"]`, else `OCL_BASE_BRANCH` : chosen on
  the sync page, saved only when that sync is applied (`OclRepo.base_branch`).
- Push webhook (`GithubWebhooksController`, HMAC `OCL_GITHUB_WEBHOOK_SECRET`) : a push to the base branch enqueues
  `RepoFrCheckJob`, which reads fr.yml through the contents API (never the shared checkout) and sets / clears
  `Setting["repo_fr_changed_at"]` (admins' sync banner, first date kept) on `SourceSync#plan.empty?` : judged on
  content, not commit authors, so merging the tool's PR isn't a change. A 404 (`GithubApi::NotFound`) flags too ;
  `OclRepo#fr_text` then raises `OclRepo::Error`, shown by the sync / publish pages. Applying a sync clears it.
- `TranslationChecks` : non-blocking warnings (text rules on any text, fr included, and comparison with the fr source) ;
  `SourceDuplicates` (`/units/duplicates`) : fr texts repeated over several keys, to factor them into `$t()`.
  Both ported from a Python lint by mobilarte.
- Progress (home cards and the translator's language switch) : `Language.stats` (translated incl. outdated, reviewed,
  over the translatable units), drawn by `shared/_progress_bar`.
- Translation history (admins only) : translator's rows and the key page (shared `_history_entry`, tinted by the
  status each revision produced). `TranslationHistory` = the language's revisions between the unit's fr changes /
  renames, `WordDiff` (word-level LCS, whitespace marked inside changes) ; the fr of a text's time is shown when a
  `source_major` came after. "Copy" refills the editor like a suggestion ; a save replaces the lazy history frame
  through a turbo-stream in the editor partial. `disclosure` panels are named (`data-disclosure-name` / `-panel-param`).
- Key page sections Translations, Comments (counts kept in step by the thread's turbo-stream ; lazy frame when folded)
  and History (lazy frame, `units#history`) fold (`collapsible`) ; state in a `section_<name>` cookie read by
  `section_open?`, so the server renders it as left.
- Help (`/help`, header link, everyone) : a guide (`help/_guide.fr` / `.en`, locale-specific partials) and a form to
  the admins. `HelpRequest` is stored first (`page` = the app path the link was clicked on, `HelpRequest.safe_page`,
  its `/translate/:lang` language), then mailed to the enabled admins (`HelpMailer`, `reply_to` the sender) when
  e-mails are on ; listed and resolved on `/help/requests`, open ones counted on the admins' header badge.
- Volunteers (`/volunteers/new`, linked from the login page, logged out only) : name, e-mail, a language among the
  targets or `config/iso_languages.yml` (ISO 639-1, own names, `rtl`) → `VolunteerRequest` (pending), nothing else
  created. Anti-spam : honeypot `website`, signed rendering time (`FormToken`, ≥ 3 s, ≤ 1 day), `rate_limit` 3/h per
  IP, closed language list, name without URL, one pending per e-mail + language, `PENDING_MAX` ; a dropped one gets
  the same thanks. Admins (`/volunteers`, badge on the Users link) accept (`accept!` : language created if new, user
  found or created, translator membership) then invite from the user's page, or reject. A stored one is mailed to the
  enabled admins (`VolunteerMailer`, `reply_to` the unverified address) when e-mails are on ; nothing to the applicant.
- `Pretranslator` (anthropic gem, `claude-opus-5-5`, structured output) only creates `Suggestion`s, never translations.
  A suggestion keeps the `source_hash` it was computed on : `Suggestion.current` (hash = the unit's) are the only
  ones shown and are never recomputed (the button and `Pretranslator#call` skip them ; nil = older rows, stale).
  Like translations, a minor fr edit moves their hash along (a major one leaves them stale) ; key renames leave them
  alone (a fr text rewritten by `rewrite_references` makes its suggestion stale). `Suggestion.store!` writes one
  (replaces the previous, refuses a blank text or a moved `source_hash`).
- Suggestions by Claude Code (`Api::SuggestionsController`, bearer `OCL_API_TOKEN`, 404 while unset) :
  `GET /api/suggestions/:language/todo?limit=` (≤ 200) = `Pretranslator#todo` (translatable, not translated or
  outdated, no current suggestion, keys' order) + `total`, `rules` (the `SYSTEM` prompt), `examples`, `strings`
  (`id`, `key`, `fr`, `en`, `note`, `source_hash`) ; `POST /api/suggestions/:language` `{ suggestions: [{ id, source_hash, text }] }`
  stores them (`origin: "claude-code"`), skipping units no longer to do (`pending`, so a current suggestion is replaced :
  corrections). Never translations.
  `GET /api/suggestions/:language/search?q=&limit=` (≤ 200, default 30) : the language's translations whose fr or text
  holds `q` (`fold`, case and accents aside), reviewed and up to date first, copies of the fr last (`key`, `fr`, `text`, `status`, `outdated`, `same_as_fr`) :
  check the vocabulary in use there before translating, not in the local database.
  To run it : the base URL and token in `.env` (`OCL_API_URL`, `OCL_API_TOKEN`, never printed), translate each batch
  following `rules` and `examples`, keep every invariant of the fr. All of `/api/*` shares `Api::BaseController`
  (bearer, target language).
- Consistency reviews by Claude Code ("vérifie la cohérence de <langue>") : `GET /api/translations/:language?offset=&limit=`
  (≤ 500, default 200) pages every translator's key in the keys' order (`id`, `key`, `fr`, `en`, `note`, `text`, `status`,
  `outdated`, current `suggestion`) ; the points found are `Issue`s (`kind` : terminology / misaligned (a text
  translating another key) / meaning / review (a suggestion to reread) / other, `body` written in English (read by every language's translators), unit nil = the whole
  language, `text` = the translation, else the suggestion, when raised). `GET /api/issues/:language?state=open|closed|all`
  lists them (check before raising one again), `POST /api/issues/:language` `{ issues: [{ key (or id), kind, body, text }] }`
  raises them (one already raised, open or resolved, is skipped with `reason` already open / resolved and its `id` : same key, kind and `text`, whatever the wording, so a rerun on unchanged translations raises nothing ; whole language or no text : same kind and body), one on a non-translatable key with `reason` not translatable, signed `origin: "OpenCutBot"` (the robot's name shown as their author). Never edits translations : the translators
  handle them on `/translate/:lang/issues` (`IssuesController`, anyone who can translate the language : state tabs and
  `issues/_search_bar` (same `search_bar_controller`) : `q` over the body, text as raised, key, fr and translation (`ListFilters::Query`,
  highlighted), `kind[]` OR-ed, `at` / `key` / `prefix` chips and their `q` keywords (a single `at` exclusive, the state kept),
  `unit` (from a panel) ; counts under the other filters, "Résolu" (like closing a GitHub issue, no confirmation, `issues/_close_button`, `card=1` + the list's filters on the page : streams for that card (`issues/_issue`) and the tabs' counts, scroll kept) sets `closed_at` + `closed_by`, reopen), those whose key left the work (archived, not translatable) hidden from translators, page and toolbar count
  (`Issue.visible_to` / `in_work`, nothing closed : they come back with the key), tagged for admins (`Issue#out_of_work`), linked from the translator's toolbar (open count),
  each row with open ones (an issues button (Remix Icon issues-line, `issue_icon`) unfolding them in a lazy panel, `issues#unit`, closable there : `row=1` answers with
  streams for the panel, status, button and approval), the pre-translation page (a column) and the key page (open count on the Translations
  header, each language's open ones under its text, in the same button + panel : `issues/_unit`). Shown as "Tickets" in fr, "Issues" in en. Also where the doubts of a suggestions
  batch go (`review`).
  An open one on a key (`Issue.contesting`, any kind) makes its translation **to review**, computed, never
  written (`Translation#contested?` / `#to_review?`, `Translation.to_review_sql`, `Issue.contested_sql`) : the "outdated"
  status filter, colour and counts (`Language.stats`, `UnitList.stats`) cover it, labelled "Ticket ouvert, à revoir", and it
  is never counted approved ; closing the issue gives the stored status back. No approval meanwhile (`TranslationOperations#save`,
  no approve button : `translations/_review_button`, given back by the streams when resolved from a panel).
- Pre-translation page (`/pretranslations`, admins, header link) : per target language, `Pretranslator#pending`
  (not translated or outdated), covered by a current suggestion (one column per `origin`), `#todo` (without one),
  stale suggestions, latest ; every column sorts (`sort` / `dir`, counts descending first) ; badges for `ANTHROPIC_API_KEY` / `OCL_API_TOKEN`. The language links to its
  translator's list filtered on not translated + outdated.
- Migration : `TransifexImport` (API v3, parallel fetch, keys mapped through the Baseline ; ours kept when edited in
  the tool = conflict), `TransifexRoster` (API exposes no e-mails).
- Import of a language's yml (`/import`, admins, `ImportsController` + `TranslationFileImport`) : keys through
  `Baseline.units_by_repo_key` (shared with `TransifexImport`), language picked or from the file name ; blank, copied
  and fr-equal values only counted, `@no-translate` ones listed read-only (`Plan#no_translate`, never written).
  Preview groups added (checked) / changed (`WordDiff`, unchecked), file kept in `tmp/imports/<token>.yml` ; picks `rows[unit_id] = Row#stamp` skip translations changed since.
  Written by `TranslationOperations#import` : `translated`, current `source_hash`, `import` revision of the chosen user.
- Export (`/export`, header link for anyone with an editable language ; `ExportsController`) : downloads a language's yml
  as `Publisher` writes it (`YamlExport#file`) ; translators their languages, admins all, fr included.

## Translator's page and editor

- CodeMirror 6 (`lib/i18n_text.js` + `i18n_text_controller`) for the editor and reference, and on the key page (fr
  source editor : nothing locked ; translations read-only, checked against the source). `Unit.refs` feeds the
  `$t()` tooltips ; Mod-click on one opens its key in a new tab, through the page's `ref_url` helper (`refs_json`) :
  `at` filter of the translator's list (none for a translator when out of their work) or, on the key page, of the keys list. Invariants (`{{ var }}`, `$t()`, HTML tags, entities) of the fr source are locked (atomic ranges +
  transaction filter), unknown ones editable in red, missing ones offered as chips. Symbols hard to type (non-ASCII `\p{S}` + `†‡`, e.g.
  `→ − °`) aren't invariants : highlighted (`tok-symbol`), offered as sky chips when fewer than in the source. The hidden textarea stays the form
  field, kept in sync ; suggestion buttons fill it and fire `input`. `¶` toggles `html.show-ws`, the key button
  `html.hide-keys` (key on hover only), both via `html_toggle_controller` (localStorage). Markdown is highlighted
  only (markers, link text, url ; urls may hold one level of parentheses, e.g. `wiki/STL_(file_format)`).
- Unsaved edits : `dirty-form` flags a form `data-dirty` (fields vs DOM defaults, `data-dirty-ignore` skips one,
  `i18n-text:change` covers the editor). Its `submit` targets are disabled and hidden (`disabled:hidden`) while clean,
  and a clean form refuses a submission through them or without a submitter (shortcuts). Not targets : save on an
  outdated translation (revalidates it), save and approve unless reviewed and up to date. `unsaved-guard` on `<body>`
  asks before a Turbo visit, a navigating submit (saves inside a turbo-frame don't) or an unload, and counts them on
  the toolbar. Mod-Enter saves, Shift-Mod-Enter saves and approves (`review` target).
- Language switch : the toolbar's language name opens a native popover (`popover_controller`) of the user's editable
  languages with their progress (only when there are several ; computed on full page loads, not the scroll frames) ;
  links keep `list_params` except `user` (offered per language).
- Reference choice (fr source / en translation) : rows render both (`translations/_reference`) when en exists, the
  `ref-en` class on the `reference` controller's wrapper shows one ; switched in place (scroll, loaded pages, unsaved
  edits kept), saved by a json PATCH. The `q` search on en follows the choice at the next search.
- Header : Keys and Translate as links, the other admin sections (`ApplicationHelper::ADMIN_MENU`) in the
  "Administration" dropdown (native popover, `admin_menu_link`), underlined when the page is one of them, carrying
  the pending volunteers' badge.
- The site header is sticky (`h-14` + 1px border) ; page toolbars (translator's list, keys list, duplicates) stick
  below it with the `.toolbar` component (`application.css`, `top: calc(3.5rem + 1px)`) : keep both in sync. It
  swallows main's `py-6` (or the repo-changed banner's `mb-4`) and spans the window through an outset border-image
  (background + bottom line).
- Language codes are shown uppercase (`language.code.upcase` : `DE`), everywhere ; only file names (`de.yml`), URLs,
  params, ids and `lang` attributes keep them lowercase.
- Flash messages are toasts (layout, `toast_controller`), centered just below the sticky header (`top-[calc(4rem+1px)]`, keep it in step with the header height) : a notice leaves after 5 s, an alert
  stays until closed ; `data-turbo-temporary` keeps them out of Turbo's cache.

## List search (translator's list and keys list)

`shared/_search_bar` + `search_bar_controller` + `ListFilters`. Every change submits the GET form ; the menu shows
each entry's count under the other filters.
- `q` searches the texts only, case and accents aside (`"…"` : exact, spaces, case and accents included,
  `Query#exact?`), matches highlighted (`SearchHelper#highlight_search`, `data-search-text` / `-exact` for the
  `i18n-text` views) ; `status[]` (not_translated / outdated / not_approved / approved, a partition) is OR-ed ;
  `questions=1`, `issues=1` (an open ticket : in the language, in any on the keys list), `warnings=1` and `days` AND-ed. `warnings` = `TranslationChecks.unit_ids`, cached on texts' count +
  max `updated_at` + the rules file's digest. `days` = `ListFilters::PERIODS`, one at a time, a revision since then
  (same kinds as the sort on the translator's list, any on the keys list).
- Chips : `key`, `prefix`, `at` with their own input ; `user` (id, hidden field) with a popover of names : users having
  revisions (in the edited language on the translator's list ; `Revision.by_user` includes Transifex imports through
  `transifex_username`). A single `at` index (no `-`) is exclusive : applying it drops the others, any other change
  drops it (`ListFilters` too ; the menu's counts leave it out).
- Keys : Mod-F focuses `q` (again in it : the browser's find), Esc blurs it and the chips' inputs, a second Esc
  within 500 ms resets the search (not Shift-Esc : Chrome's task manager) ; Enter and the reset keep the focus across
  the Turbo visit (sessionStorage flag). On Enter, `#120` / `#120-180`, `key:…`, `branch:…`, `user:…` (a name or its
  start, `_` for a space, left in `q` unless exactly one matches) words of `q` move to their chip.
- Users page : its own `users/_search_bar` (same look, same `search_bar_controller`) over `UserList` (in memory) :
  `q` (name, e-mail, logins), `language` (a list chip, like `user`), `role[]` OR-ed (narrowed to the language, `disabled` too),
  `days` (activity, or `never`), `seen` (same periods over `User#last_seen_at` : any request, consultation included,
  written by `ApplicationController#record_last_seen` at most every `User::SEEN_PRECISION` through `update_column`, so
  the login tokens' `updated_at` stays put), sorts name / email / languages (codes) / activity / seen (default, `UserList::DEFAULT_SORT`) / contributions /
  created, from the sort menu or the table's column headers (`UsersHelper`, shared `sort_header_link` with `/pretranslations`).
- Disabling a user (`disabled_at`, `User.enabled`) : no login link, session dropped at the next request
  (`current_user`), no comment e-mail nor invitation ; memberships and history kept. Not oneself.
- Invitations sent : `Invitation(user, inviter, email)`, written by `InvitationMailer`'s `after_deliver` only when
  `perform_deliveries` (e-mails off = no trace), listed under the "resend" button of the user's page.
- Sort (translator's list only, `sorts:` local) : `sort` = `index` (default) / `updated` (last revision in the language
  or fr source one, `TranslationsController::SOURCE_KINDS`, never revised last), `dir`. Not a filter : its own menu,
  a sky chip whose arrow reverses it (removed by "remove all" / Esc twice), kept by a single `at`.

## YAML I/O

- Read through Psych nodes (raw scalars) : `no: No` must stay "No". gulp uses js-yaml (YAML 1.2), so unquoted Yes/No
  in OCL files are not a bug.
- Writer : plain scalar if `Psych.safe_load` round-trips, else literal block `|`/`|-`/`|+`, else double quotes with
  custom escaping (not `to_json`, which escapes `<`).
- Transifex exports untranslated strings as `""` ; gulp falls back to en for `""` and missing keys alike, so import
  skips `""`.

## Gotchas

- Tailwind sources are explicit (`source(none)` + `@source` views / helpers / javascript) : the deployed copy has no
  `.git`, so auto-detection scanned `vendor/bundle`. Classes used elsewhere need a new `@source`.
- Tailwind arbitrary values turn `_` into spaces : escape it in selectors (`group-has-[#user\_admin\_1:checked]/user:hidden`),
  and check the built rule in `app/assets/builds/tailwind.css`.
- Turbo ignores a 200 HTML answer to a form POST : forms that render a page need `data: { turbo: false }`.
- Turbo hover prefetch fires GETs : single-use tokens are consumed by POST (login confirm page).
- `Unit` default_scope `order(:position)` leaks through `merge` : use `reorder`.
- SQLite `LIKE` ignores `sanitize_sql_like`'s backslash escapes without `ESCAPE '\'` : always write
  `"… LIKE ? ESCAPE '\\'"`, or any key with a `_` matches nothing.
- SQLite `LIKE` folds ASCII case only (`'Ø' LIKE 'ø'` is false) : text searches use `fold(column) LIKE` with a folded
  pattern (`SqliteFold.fold`, case and accents aside, registered by `config/initializers/sqlite_fold.rb`).
- Restoring the SQLite db by file copy breaks with WAL files : `db:reset` + bootstrap instead.
- CodeMirror rewrites its root element's `class` attribute (e.g. on focus) : pass classes through
  `EditorView.editorAttributes` (`className` option), never `classList.add`. No font size in the CM theme either :
  it beats the Tailwind `text-sm` on the same element.
- Curl tests : login via `User#generate_token_for(:login)` (`rails runner`), then GET + POST `/login/<token>` (the dev
  login form is rate limited to 5 per 10 min) ; use both `-c` and `-b` (the session cookie carries the CSRF token).

## Testing harnesses (keep them in the scratchpad, never in the repo)

- Local OCL repo : `git clone --bare --depth 1 --branch 8.0.0 file://<ocl repo>` + `OCL_REPO_URL`.
- Fake Anthropic server via the client's `base_url` ; fake Transifex (port 7858) via `TRANSIFEX_API_URL` ; fake GitHub
  API via `OCL_GITHUB_API_URL` (+ `OCL_GITHUB_WEB_URL` for the OAuth endpoints).
- Editor JS without a browser : Node + jsdom, vendored CodeMirror files copied into a scratch `node_modules` (one
  package dir per bare specifier, `"type": "module"`) ; `npm i` prunes them. Expose jsdom's `window`, `document`,
  `Window`… as globals before importing the module.

## Working with the user

- Answer in French (chat, progress lines between tool calls) ; code, comments and commit messages stay in English.
- The user commits themselves : never commit, never offer to.
- Never use `git stash` (or any index-touching command) for a baseline.
