Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope "(:locale)", locale: /en|pl/ do
    get "declaration", to: "pages#declaration", as: :declaration

    # Adresy z poprzedniej wersji – prowadzą do nich kody QR na wydanych zaświadczeniach i istniejące linki.
    get "certificates", to: "certificates#new"
    get "certificates/new", to: "certificates#new"
    get "certificates/declaration", to: redirect { |params, _| "/#{params[:locale] || I18n.default_locale}/declaration" }

    constraints category: /maritime|aeronautical|amateur/ do
      get  "certificates/:category", to: "certificates#new", as: :category_certificates
      post "certificates/:category", to: "certificates#create"
      post "certificates/:category/statement", to: "statements#create", as: :category_statement
    end

    root "certificates#new"
  end
end
