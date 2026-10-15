Rails.application.routes.draw do
  root "languages#index"

  resource :session, only: [:new, :create, :destroy]
  patch "locale", to: "locales#update", as: :locale
  get "login/:token", to: "sessions#show", as: :login
  post "login/:token", to: "sessions#consume"

  # Translators
  get "translate", to: "languages#index", as: :translate_root
  get "translate/:lang", to: "translations#index", as: :translate
  patch "translate/reference", to: "reference_languages#update", as: :reference_language
  patch "translate/:lang/:unit_id", to: "translations#update", as: :translate_unit
  get "translate/:lang/:unit_id/history", to: "translations#history", as: :translate_unit_history
  post "translate/:lang/pretranslate", to: "translations#pretranslate", as: :pretranslate
  # Points raised by a consistency review, closed by the language's translators
  get "translate/:lang/issues", to: "issues#index", as: :issues
  patch "issues/:id/close", to: "issues#close", as: :close_issue
  get "translate/:lang/:unit_id/issues", to: "issues#unit", as: :translate_unit_issues
  # A language's yml, downloaded by its translators (and admins, fr included)
  get "export", to: "exports#index", as: :exports
  get "export/:lang", to: "exports#show", as: :export

  # Everyone : the guide and the form to the admins (who list and resolve the requests)
  get "help", to: "help#show", as: :help
  resources :help_requests, path: "help/requests", only: [:index, :create] do
    patch :resolve, on: :member
  end

  # Anyone without an account offers to translate a language (from the login page) ; admins accept or reject
  resources :volunteers, only: [:index, :new, :create] do
    member do
      patch :accept
      patch :reject
    end
  end

  # Admins
  resources :units, only: [:index, :show] do
    get :duplicates, on: :collection
    resources :comments, only: [:index, :create]
    member do
      get :history
      patch :rename
      patch :source
      patch :note
      patch :archive
    end
  end
  patch "comments/:id/resolve", to: "comments#resolve", as: :resolve_comment
  patch "branches/rename", to: "branches#rename", as: :rename_branch
  patch "branches/note", to: "branches#note", as: :branch_note
  resources :users, except: [:show] do
    member do
      post :invite
      patch :disable
      patch :enable
      get :history
    end
  end

  get "sync", to: "syncs#new", as: :new_sync
  post "sync/repo", to: "syncs#repo", as: :sync_repo
  post "sync", to: "syncs#preview", as: :sync_preview
  post "sync/apply", to: "syncs#apply", as: :sync_apply
  get "import", to: "imports#new", as: :new_import
  post "import", to: "imports#preview", as: :import_preview
  post "import/apply", to: "imports#apply", as: :import_apply

  get "pretranslations", to: "pretranslations#index", as: :pretranslations
  resources :publications, only: [:index, :create] do
    post :preview, on: :collection
  end
  post "github/connect", to: "github_accounts#connect", as: :connect_github
  get "github/callback", to: "github_accounts#callback", as: :github_callback
  delete "github/connect", to: "github_accounts#disconnect", as: :disconnect_github
  get "migration", to: "migrations#show", as: :migration
  post "migration/analyze", to: "migrations#analyze", as: :migration_analyze
  post "migration/apply", to: "migrations#apply", as: :migration_apply
  get "migration/roster", to: "migrations#roster", as: :migration_roster
  post "migration/invite", to: "migrations#invite", as: :migration_invite
  post "github/webhook", to: "github_webhooks#create"

  # Suggestions written by Claude Code (OCL_API_TOKEN)
  get "api/suggestions/:language/todo", to: "api/suggestions#todo"
  get "api/suggestions/:language/search", to: "api/suggestions#search"
  post "api/suggestions/:language", to: "api/suggestions#create"

  # Consistency reviews by Claude Code : a language's texts, the points raised (closed on the issues page)
  get "api/translations/:language", to: "api/translations#index"
  get "api/issues/:language", to: "api/issues#index"
  post "api/issues/:language", to: "api/issues#create"

  get "up" => "rails/health#show", as: :rails_health_check
end
