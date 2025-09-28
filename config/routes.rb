# config/routes.rb
Rails.application.routes.draw do
  root "salesforce_dashboard#index"

  get "api/salesforce", to: "salesforce_dashboard#api_data"
  post "api/salesforce-ai-query", to: "salesforce_dashboard#ai_query"
  post "api/salesforce-reset-chat", to: "salesforce_dashboard#reset_chat"
  get "api/salesforce-chat-status", to: "salesforce_dashboard#chat_status"
  get "api/salesforce-health", to: "salesforce_dashboard#health_check"

  post "api/ai-query", to: "salesforce_dashboard#ai_query"
  post "api/reset-chat", to: "salesforce_dashboard#reset_chat"
  get "api/chat-status", to: "salesforce_dashboard#chat_status"
  get "api/health", to: "salesforce_dashboard#health_check"

  get "*path", to: "salesforce_dashboard#index", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
