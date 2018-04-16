module DelayedCronJob
  module ActiveJob
    module QueueAdapter

      def self.included(klass)
        klass.send(:alias_method, :enqueue, :enqueue_with_cron)
        klass.send(:alias_method, :enqueue_at, :enqueue_at_with_cron)
      end

      def self.extended(klass)
        meta = class << klass; self; end
        meta.send(:alias_method, :enqueue, :enqueue_with_cron)
        meta.send(:alias_method, :enqueue_at, :enqueue_at_with_cron)
      end

      def enqueue_with_cron(job)
        enqueue_at(job, nil)
      end

      def enqueue_at_with_cron(job, timestamp)
        options = { queue: job.queue_name,
                    cron: job.cron  }
        options[:run_at] = Time.at(timestamp) if timestamp
        options[:priority] = job.priority if job.respond_to?(:priority)
        wrapper = ::ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(job.serialize)
        delayed_job = Delayed::Job.enqueue(wrapper, options)
        job.provider_job_id = delayed_job.id if job.respond_to?(:provider_job_id=)
        preserve_job_item_reference_type_and_id(delayed_job, job)
        delayed_job
      end

      # Introduces an additional save but is the naive implementation
      # allowing us to save ActiveRecord instance type and id
      def preserve_job_item_reference_type_and_id(delayed_job, job)
        if !delayed_job.respond_to?(:delayed_reference_id)
          return false
        end

        job_item = job.arguments.first

        if job_item.respond_to?(:id)
          delayed_job.update_attributes(
            delayed_reference_id: job_item.id,
            delayed_reference_type: job_item.class.name
          )
        end
      end

    end
  end
end
