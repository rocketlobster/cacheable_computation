module CacheableComputation

  def self.included base
    base.extend ClassMethods
    base.class_eval do

      attr_accessible :data_type, :frequency, :endtime, :specific_value
      before_create :compute

      def compute
        self.endtime = self.class.endtime_for frequency, endtime
        self.computation = send "compute_#{data_type}", frequency, endtime, specific_value
        unless persisted?
          old_data = self.class.where(data_type: data_type, frequency: frequency, endtime: endtime, specific_value: specific_value)
          old_data.destroy_all
        end
      end

      def endtime_for frequency, time
        self.class.entime_for frequency, time
      end

      def time_range frequency, endtime
        self.class.time_range frequency, endtime
      end

    end
  end

  module ClassMethods

    def find_with options
      endtime = options[:endtime]
      endtime ||= Time.parse("#{options[:day]}/#{options[:month]}/#{options[:year]}")
      endtime = Time.now if Time.now - endtime > 2.year
      retrieve_or_compute options[:data_type], options[:frequency], endtime
    end

    def retrieve_or_compute data_type, frequency, endtime, specific_value
      result = retrieve data_type, frequency, endtime, specific_value
      if result
        yield result if block_given?
        result.computation
      else
        new_result = create(data_type: data_type, frequency: frequency, endtime: endtime, specific_value: specific_value)
        new_result.computation
      end
    end

    def compute data_type, frequency, endtime, specific_value = nil
      retrieve_or_compute(data_type, frequency, endtime, specific_value) { |result| result.compute }
    end

    def retrieve data_type, frequency, endtime, specific_value = nil
      endtime = endtime_for frequency, endtime
      if specific_value
        where(data_type: data_type, frequency: frequency, endtime: endtime, specific_value: specific_value).first
      else
        where(data_type: data_type, frequency: frequency, endtime: endtime).first
      end
    end

    def endtime_for frequency, time
      (frequency == :ever) ?  time : time.send(:"end_of_#{frequency}")
    end

    def time_range frequency, endtime
      endtime.send(:"beginning_of_#{frequency}")..endtime.send(:"end_of_#{frequency}")
    end

  end

end
