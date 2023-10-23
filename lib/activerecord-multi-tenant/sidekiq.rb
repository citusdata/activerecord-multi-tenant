# frozen_string_literal: true

require 'sidekiq/client'

# Adds methods to handle tenant information both in the client and server.
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

# Configure Sidekiq to use the multi-tenant client and server middleware to add (client/server)/process(server)
# tenant information.
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

# Bulk push support for Sidekiq while setting multi-tenant information.
# This is a copy of the Sidekiq::Client#push_bulk method with the addition of
# setting the multi-tenant information for each job.
module Sidekiq
  class Client
    # Allows the caller to enqueue multiple Sidekiq jobs with
    # tenant information in a single call. It ensures that each job is processed
    # within the correct tenant context and returns an array of job IDs for the enqueued jobs
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

    # Enabling the push_bulk_with_tenants method to be called directly on the Sidekiq::Client class
    class << self
      def push_bulk_with_tenants(items)
        new.push_bulk_with_tenants(items)
      end
    end
  end
end
