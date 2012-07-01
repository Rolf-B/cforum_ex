Cforum::Application.routes.draw do
  # thread urls
  get '/' => 'cf_threads#index', as: 'cf_threads'
  post '/' => 'cf_threads#create'
  get '/new' => 'cf_threads#new', as: 'new_cf_thread'
  get '/:year/:mon/:day/:tid' => 'cf_threads#show', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/, as: 'cf_thread'
  delete '/:year/:mon/:day/:tid' => 'cf_threads#destroy', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/

  # message urls
  get '/:year/:mon/:day/:tid/:mid' => 'cf_messages#show', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/, as: 'cf_message'
  get '/:year/:mon/:day/:tid/:mid/edit' => 'cf_messages#edit', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/, as: 'edit_cf_message'
  put '/:year/:mon/:day/:tid/:mid' => 'cf_messages#update', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/
  delete '/:year/:mon/:day/:tid/:mid' => 'cf_messages#destroy', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/

  get '/:year/:mon/:day/:tid/:mid/new' => 'cf_messages#new', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/, as: 'new_cf_message'
  post '/:year/:mon/:day/:tid/:mid' => 'cf_messages#create', :year => /\d{4}/, :mon => /\w{3}/, :day => /\d{1,2}/

  resources :users

  match '/login' => 'application#login_from_http_basic'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
  root to: 'cf_threads#index'
end
