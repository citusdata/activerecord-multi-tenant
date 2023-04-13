require 'sidekiq/client'

module Sidekiq::Middleware::MultiTenant
  # Get the current tenant and store in the message to be sent to Sidekiq.
  class Client
    def call(_worker_class, msg, _queue, _redis_pool)
      if MultiTenant.current_tenant.present?
        msg['multi_tenant'] ||=
          {
            'class' => MultiTenant.current_tenant_class,
            'id' => MultiTenant.current_tenant_id
          }
      end

      yield
    end
  end

  # Pull the tenant out and run the current thread with it.
  class Server
    def call(_worker_class, msg, _queue, &block)
      if msg.key?('multi_tenant')
        tenant = begin
          msg['multi_tenant']['class'].constantize.find(msg['multi_tenant']['id'])
        rescue ActiveRecord::RecordNotFound
          msg['multi_tenant']['id']
        end
        MultiTenant.with(tenant, &block)
      else
        yield
      end
    end
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::MultiTenant::Server
  end
  config.client_middleware do |chain|
    chain.add Sidekiq::Middleware::MultiTenant::Client
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Middleware::MultiTenant::Client
  end
end

module Sidekiq
  class Client
    def push_bulk_with_tenants(items)
      first_job = items['jobs'].first
      return [] unless first_job # no jobs to push
      unless first_job.is_a?(Hash)
        raise ArgumentError, "Bulk arguments must be an Array of Hashes: [{ 'args' => [1], 'tenant_id' => 1 }, ...]"
      end

      normed = normalize_item(items.except('jobs').merge('args' => []))
      payloads = items['jobs'].map do |job|
        MultiTenant.with(job['tenant_id']) do
          copy = normed.merge('args' => job['args'], 'jid' => SecureRandom.hex(12), 'enqueued_at' => Time.now.to_f)
          result = process_single(items['class'], copy)
          result || nil
        end
      end.compact

      raw_push(payloads) unless payloads.empty?
      payloads.collect { |payload| payload['jid'] }
    end

    class << self
      def push_bulk_with_tenants(items)
        new.push_bulk_with_tenants(items)
      end
    end
  end
end
