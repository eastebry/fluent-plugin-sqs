module Fluent

    require 'aws-sdk'

    class SQSOutput < BufferedOutput

        Fluent::Plugin.register_output('sqs', self)

        include SetTagKeyMixin
        config_set_default :include_tag_key, false

        include SetTimeKeyMixin
        config_set_default :include_time_key, true

        config_param :aws_key_id, :string, :default => nil
        config_param :aws_sec_key, :string, :default => nil
        config_param :queue_name, :string
        config_param :create_queue, :bool, :default => true
        config_param :region, :string, :default => 'us-east-1'
        config_param :delay_seconds, :integer, :default => 0
        config_param :include_tag, :bool, :default => true
        config_param :tag_property_name, :string, :default => '__tag'

        def configure(conf)
            super
        end

        def start
            super

            AWS.config(
                :access_key_id => @aws_key_id,
                :secret_access_key => @aws_sec_key)

            @sqs = AWS::SQS.new(
                :region => @region)
            if @create_queue then
                @queue = @sqs.queues.create(@queue_name)
            else
                @queue = @sqs.queues.named(@queue_name)
            end
        end

        def shutdown
            super
        end

        def format(tag, time, record)
            if @include_tag then
                record[@tag_property_name] = tag
            end

            record.to_msgpack
        end

        def write(chunk)
            records = []
            chunk.msgpack_each {|record| records << { :message_body => record.to_json, :delay_seconds => @delay_seconds } }
            until records.length <= 0 do
                @queue.batch_send(records.slice!(0..9))
            end
        end
    end
end
