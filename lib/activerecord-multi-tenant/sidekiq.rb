require 'sidekiq/client'

module Sidekiq::Middleware::MultiTenant
  # Get the current tenant and store in the message to be sent to Sidekiq.
  class Client
    def call(worker_class, msg, queue, redis_pool)
      msg['multi_tenant'] ||=
        {
          'class' => MultiTenant.current_tenant_class,
          'id' => MultiTenant.current_tenant_id
        } if MultiTenant.current_tenant.present?

      yield
    end
  end

  # Pull the tenant out and run the current thread with it.
  class Server
    def call(worker_class, msg, queue)
      if msg.has_key?('multi_tenant')
        tenant = msg['multi_tenant']['class'].constantize.find(msg['multi_tenant']['id'])
        MultiTenant.with(tenant) do
          yield
        end
      else
        yield
      end
    end
  end
end

module Sidekiq
  class Client
    def push_bulk_with_tenants(items)
      job = items['jobs'].first
      return [] unless job # no jobs to push
      raise ArgumentError, "Bulk arguments must be an Array of Hashes: [{ 'args' => [1], 'tenant_id' => 1 }, ...]" if !job.is_a?(Hash)

      normed = normalize_item(items.except('jobs').merge('args' => []))
      payloads = items['jobs'].map do |job|
        MultiTenant.with(job['tenant_id']) do
          copy = normed.merge('args' => job['args'], 'jid' => SecureRandom.hex(12), 'enqueued_at' => Time.now.to_f)
          result = process_single(items['class'], copy)
          result ? result : nil
        end
      end.compact

      raw_push(payloads) if !payloads.empty?
      payloads.collect { |payload| payload['jid'] }
    end

    class << self
      def push_bulk_with_tenants(items)
        new.push_bulk_with_tenants(items)
      end
    end
  end
end
