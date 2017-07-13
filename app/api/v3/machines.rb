module V3
  class Machines < Grape::API
    helpers MachineHelpers
    helpers V3::Helpers

    version 'v3'
    format :json

    resource :machines do
      before do
        api_enabled!
        authenticate!
        set_papertrail
        @owner = get_owner
      end

      route_param :fqdn, type: String, requirements: { fqdn: /[a-zA-Z0-9.-]+/ } do
        resource :attachments do
          route_param :fingerprint, type: String, requirements: { fingerprint: /[a-f0-9]+/ } do
            desc 'Get an attachment' do
              success Attachment::Entity
            end
            get do
              can_read!
              a = Attachment.find_by_attachment_fingerprint params[:fingerprint]
              error!('Not Found', 404) unless a

              present a
            end

            desc 'Delete an attachment'
            delete do
              can_write!
              a = Attachment.find_by_attachment_fingerprint params[:fingerprint]
              error!('Not Found', 404) unless a

              a.destroy!
            end
          end

          desc 'Get all attachments', is_array: true,
                                      success: Attachment::Entity
          get do
            can_read!
            m = Machine.find_by_fqdn params[:fqdn]
            error!('Not Found', 404) unless m

            present m.attachments
          end

          desc 'Create an attachment', success: Attachment::Entity
          params do
            requires :data, type: Rack::Multipart::UploadedFile
          end
          post do
            can_write!
            m = Machine.find_by_fqdn params[:fqdn]
            error!('Not Found', 404) unless m

            x = {
              filename: params[:data][:filename],
              size: params[:data][:tempfile].size,
              tempfile: params[:data][:tempfile]
            }

            attachment = ActionDispatch::Http::UploadedFile.new(x)

            present m.attachments.create(attachment: attachment, owner: m.owner)
          end
        end

        resource :aliases do
          route_param :alias, type: String, requirements: { alias: /[a-zA-Z0-9.-]+/ } do
            desc 'Get a alias', success: MachineAlias::Entity
            get do
              can_read!
              a = MachineAlias.find_by_name params[:alias]
              error!('Not Found', 404) unless a
              present a
            end

            desc 'Update an alias', success: MachineAlias::Entity
            params do
              requires :name, type: String, documentation: { type: "String", desc: "New alias" }
            end
            put do
              can_write!
              a = MachineAlias.find_by_name params[:alias]
              error!('Not Found', 404) unless a

              p = declared(params, include_parent_namespaces: false).to_h

              a.update_attributes(p)
              present a
            end

            desc 'Delete an alias'
            delete do
              can_write!
              a = MachineAlias.find_by_name params[:alias]
              error!('Not Found', 404) unless a
              a.destroy
            end
          end

          desc 'Get all aliases', is_array: true,
                                  success: MachineAlias::Entity
          get do
            can_read!
            m = Machine.find_by_fqdn params[:fqdn]
            error!('Not Found', 404) unless m

            present m.aliases
          end

          desc 'Create an alias', success: MachineAlias::Entity
          params do
              requires :name, type: String, documentation: { type: "String", desc: "New alias" }
          end
          post do
            can_write!
            m = Machine.find_by_fqdn params[:fqdn]
            error!('Not Found', 404) unless m

            p = declared(params, include_parent_namespaces: false).to_h
            p['machine'] = m

            a = MachineAlias.create(p)
            present a
          end
        end

        resource :nics do
          route_param :name, type: String, requirements: { name: /[a-zA-Z0-9.-]+/ } do
            desc 'Get a nic', success: Nic::Entity
            get do
              can_read!
              m = Machine.find_by_fqdn params[:fqdn]
              error!('Not Found', 404) unless m

              n = Nic.where(machine_id: m.id, name: params[:name])
              error!('Not Found', 404) unless n
              present n
            end

            desc 'Update a nic', success: Nic::Entity
            put do
              can_write!
              m = Machine.find_by_fqdn params[:fqdn]
              error!('Not Found', 404) unless m

              n = Nic.where(machine_id: m.id, name: params[:name])
              error!('Not Found', 404) unless n

              p = params.select { |k| Nic.attribute_method?(k) }

              n.update_attributes(p)
              present n
            end

            desc 'Delete a nic'
            delete do
              can_write!
              m = Machine.find_by_fqdn params[:fqdn]
              error!('Not Found', 404) unless m

              n = Nic.find_by machine_id: m.id, name: params[:name]
              error!('Not Found', 404) unless n

              n.destroy
            end
          end

          desc 'Get all nics', is_array: true,
                               success: Nic::Entity
          get do
            can_read!
            m = Machine.find_by_fqdn params[:fqdn]
            error!('Not Found', 404) unless m

            present m.nics
          end

          desc 'Create a nic', success: Nic::Entity
          post do
            can_write!
            m = Machine.find_by_fqdn params[:fqdn]
            error!('Not Found', 404) unless m

            nic_p = params.select { |k| Nic.attribute_method?(k) }
            ip_address_p = params['ip_address'].select { |k| IpAddress.attribute_method?(k) }

            i = IpAddress.new(ip_address_p)

            nic_p.delete('ip_address')
            nic_p['ip_address'] = i
            nic_p['machine'] = m
            n = Nic.create!(nic_p)

            present n
          end
        end

        desc 'Get a machine by fqdn', success: Machine::Entity
        get do
          can_read!
          m = Machine.find_by_fqdn params[:fqdn]
          error!('Not Found', 404) unless m

          present m
        end

        desc 'Update a single machine', success: Machine::Entity
        params do
          requires :fqdn,                   type: String,   documentation: { type: "String",  desc: "FQDN" }
          optional :os,                     type: String,   documentation: { type: "String",  desc: "Operating system" }
          optional :os_release,             type: String,   documentation: { type: "String",  desc: "Operating system release" }
          optional :arch,                   type: String,   documentation: { type: "String",  desc: "Architecture" }
          optional :ram,                    type: Integer,  documentation: { type: "Integer", desc: "RAM" }
          optional :cores,                  type: Integer,  documentation: { type: "Integer", desc: "CPU Cores" }
          optional :vmhost,                 type: String,   documentation: { type: "String",  desc: "VM host" }
          optional :serviced_at,            type: String,   documentation: { type: "String",  desc: "Service date" }
          optional :description,            type: String,   documentation: { type: "String",  desc: "Description" }
          optional :uptime,                 type: Integer,  documentation: { type: "Integer", desc: "Uptime in seconds" }
          optional :serialnumber,           type: String,   documentation: { type: "String",  desc: "Serial number" }
          optional :backup_type,            type: Integer,  documentation: { type: "Integer", desc: "Backup type" }
          optional :auto_update,            type: Boolean,  documentation: { type: "Bool",    desc: "True if the machine is updated automatically" }
          optional :switch_url,             type: String,   documentation: { type: "String",  desc: "Switch management URL" }
          optional :mrtg_url,               type: String,   documentation: { type: "String",  desc: "MRTG URL" }
          optional :config_instructions,    type: String,   documentation: { type: "String",  desc: "'Config instructions'" }
          optional :sw_characteristics,     type: String,   documentation: { type: "String",  desc: "'Software characteristics'" }
          optional :business_purpose,       type: String,   documentation: { type: "String",  desc: "'Business purpose'" }
          optional :business_criticality,   type: String,   documentation: { type: "String",  desc: "'Business criticality'" }
          optional :business_notification,  type: String,   documentation: { type: "String",  desc: "'Business notification'" }
          optional :diskspace,              type: Integer,  documentation: { type: "Integer", desc: "Disc space in bytes" }
          optional :severity_class,         type: String,   documentation: { type: "String",  desc: "" }
          optional :ucs_role,               type: String,   documentation: { type: "String",  desc: "" }
          optional :backup_brand,           type: String,   documentation: { type: "String",  desc: "" }
          optional :backup_last_full_run,   type: String,   documentation: { type: "String",  desc: "Last full backup timestamp" }
          optional :backup_last_inc_run,    type: String,   documentation: { type: "String",  desc: "Last incremental backup timestamp" }
          optional :backup_last_diff_run,   type: String,   documentation: { type: "String",  desc: "Last differential backup timestamp" }
          optional :backup_last_full_size,  type: String,   documentation: { type: "String",  desc: "Last full backup size" }
          optional :backup_last_inc_size,   type: String,   documentation: { type: "String",  desc: "Last incremental backup size" }
          optional :backup_last_diff_size,  type: String,   documentation: { type: "String",  desc: "Last differential backup size" }
          optional :needs_reboot,           type: Integer,  documentation: { type: "String",  desc: "Needs reboot" }
          optional :software,               type: Array,    documentation: { type: "JSON",    desc: "Known installed doftware packages" }
          optional :power_feed_a,           type: Integer,  documentation: { type: "Integer", desc: "Location id of power feed a" }
          optional :power_feed_b,           type: Integer,  documentation: { type: "Integer", desc: "Location id of power feed b" }
        end
        put do
          can_write!
          m = Machine.find_by_fqdn params[:fqdn]
          error!('Not Found', 404) unless m

          p = declared(params).to_h

          m.update_attributes(p)

          is_backed_up = false
          if
            (p['backup_brand'] && p['backup_brand'].to_i > 0) ||
            !p['backup_last_full_run'].blank? ||
            !p['backup_last_inc_run'].blank? ||
            !p['backup_last_diff_run'].blank? ||
            !p['backup_last_full_size'].blank? ||
            !p['backup_last_inc_size'].blank? ||
            !p['backup_last_diff_size'].blank?

            is_backed_up = true
          end

          m.backup_type = 1 if is_backed_up

          m.power_feed_a = params[:power_feed_a_id] ? Location.find_by_id(params[:power_feed_a_id]) : m.power_feed_a
          m.power_feed_b = params[:power_feed_b_id] ? Location.find_by_id(params[:power_feed_b_id]) : m.power_feed_b

          m.save

          present m
        end

        desc 'Delete a machine'
        delete do
          can_write!
          m = Machine.find_by_fqdn params[:fqdn]
          error!('Not Found', 404) unless m
          m.destroy
        end
      end

      desc 'Return a list of machines, possibly filtered', is_array: true,
                                                           success: Machine::Entity
      get do
        can_read!

        # first get all machines
        query = Machine.all

        # strip possible idb_api_token parameter, this isn't a key of machines
        params.delete('idb_api_token')

        # then add a where condition for each parameter of the request
        params.each do |key, value|
          # arel_table uses symbols to get a symbol from the key string
          keysym = key.to_sym
          # merge AND connects the next "where" condition, which is build using arel_table of Machine
          # (http://www.rubydoc.info/github/rails/arel/Arel/Table)
          query = query.merge(Machine.where(Machine.arel_table[keysym].eq(value)))
        end

        # test if there were any keys which are no column names.
        # otherwise the exception would be thrown when rendering.
        # return 400 for such a request.
        begin
          error!('Not Found', 404) unless query.any?
        rescue ActiveRecord::StatementInvalid
          error!('Bad Request', 400)
        end

        present query
      end

      desc 'Create a new machine', success: Machine::Entity
      params do
        requires :fqdn,                   type: String,   documentation: { type: "String",  desc: "FQDN" }
        optional :os,                     type: String,   documentation: { type: "String",  desc: "Operating system" }
        optional :os_release,             type: String,   documentation: { type: "String",  desc: "Operating system release" }
        optional :arch,                   type: String,   documentation: { type: "String",  desc: "Architecture" }
        optional :ram,                    type: Integer,  documentation: { type: "Integer", desc: "RAM" }
        optional :cores,                  type: Integer,  documentation: { type: "Integer", desc: "CPU Cores" }
        optional :vmhost,                 type: String,   documentation: { type: "String",  desc: "VM host" }
        optional :serviced_at,            type: String,   documentation: { type: "String",  desc: "Service date" }
        optional :description,            type: String,   documentation: { type: "String",  desc: "Description" }
        optional :uptime,                 type: Integer,  documentation: { type: "Integer", desc: "Uptime in seconds" }
        optional :serialnumber,           type: String,   documentation: { type: "String",  desc: "Serial number" }
        optional :backup_type,            type: Integer,  documentation: { type: "Integer", desc: "Backup type" }
        optional :auto_update,            type: Boolean,  documentation: { type: "Bool",    desc: "True if the machine is updated automatically" }
        optional :switch_url,             type: String,   documentation: { type: "String",  desc: "Switch management URL" }
        optional :mrtg_url,               type: String,   documentation: { type: "String",  desc: "MRTG URL" }
        optional :config_instructions,    type: String,   documentation: { type: "String",  desc: "'Config instructions'" }
        optional :sw_characteristics,     type: String,   documentation: { type: "String",  desc: "'Software characteristics'" }
        optional :business_purpose,       type: String,   documentation: { type: "String",  desc: "'Business purpose'" }
        optional :business_criticality,   type: String,   documentation: { type: "String",  desc: "'Business criticality'" }
        optional :business_notification,  type: String,   documentation: { type: "String",  desc: "'Business notification'" }
        optional :diskspace,              type: Integer,  documentation: { type: "Integer", desc: "Disc space in bytes" }
        optional :severity_class,         type: String,   documentation: { type: "String",  desc: "" }
        optional :ucs_role,               type: String,   documentation: { type: "String",  desc: "" }
        optional :backup_brand,           type: String,   documentation: { type: "String",  desc: "" }
        optional :backup_last_full_run,   type: String,   documentation: { type: "String",  desc: "Last full backup timestamp" }
        optional :backup_last_inc_run,    type: String,   documentation: { type: "String",  desc: "Last incremental backup timestamp" }
        optional :backup_last_diff_run,   type: String,   documentation: { type: "String",  desc: "Last differential backup timestamp" }
        optional :backup_last_full_size,  type: String,   documentation: { type: "String",  desc: "Last full backup size" }
        optional :backup_last_inc_size,   type: String,   documentation: { type: "String",  desc: "Last incremental backup size" }
        optional :backup_last_diff_size,  type: String,   documentation: { type: "String",  desc: "Last differential backup size" }
        optional :needs_reboot,           type: Integer,  documentation: { type: "String",  desc: "Needs reboot" }
        optional :software,               type: Array,    documentation: { type: "JSON",    desc: "Known installed doftware packages" }
        optional :power_feed_a,           type: Integer,  documentation: { type: "Integer", desc: "Location id of power feed a" }
        optional :power_feed_b,           type: Integer,  documentation: { type: "Integer", desc: "Location id of power feed b" }
      end
      post do
        can_write!
        p = declared(params).to_h # we need to_h here as active record doesn't like the hashie mash params
        begin
          m = Machine.new(p)
          m.owner = @owner
          m.save!
        rescue ActiveRecord::RecordInvalid
          error!('Invalid Machine', 409)
        end
        present m
      end
    end
  end
end