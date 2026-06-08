module Salopulse
  class Railtie < ::Rails::Railtie
    initializer "salopulse.middleware" do |app|
      app.middleware.use(Salopulse::Instrumentation::RackMiddleware)
    end

    initializer "salopulse.active_record" do
      ActiveSupport.on_load(:active_record) do
        Salopulse::Instrumentation::ActiveRecordSubscriber.subscribe(Salopulse::Client.instance)
      end
    end

    initializer "salopulse.sidekiq" do
      if defined?(::Sidekiq)
        require_relative "instrumentation/sidekiq"
        Salopulse::Instrumentation::Sidekiq.install!
      end
    end

    config.after_initialize do
      client = Salopulse::Client.instance
      if client.uninitialized? && ENV["SALOPULSE_DSN"]
        Salopulse.init(dsn: ENV["SALOPULSE_DSN"], release: ENV["GIT_SHA"], environment: defined?(Rails) ? Rails.env : nil)
      end
    end
  end
end
