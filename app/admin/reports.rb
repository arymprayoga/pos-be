# frozen_string_literal: true

require "csv"

ActiveAdmin.register_page "Reports" do
  menu priority: 4, label: "Reports"

  content title: "Business Intelligence Reports" do
    # Report Filters Panel
    panel "Report Filters" do
      form method: :get, class: "report-filters" do
        div class: "filter-row" do
          label "Date Range:", for: "date_range"
          select name: "date_range", id: "date_range" do
            option value: "7", selected: (params[:date_range] == "7" ? "selected" : nil) do
              "Last 7 days"
            end
            option value: "30", selected: (params[:date_range] == "30" ? "selected" : nil) do
              "Last 30 days"
            end
            option value: "90", selected: (params[:date_range] == "90" ? "selected" : nil) do
              "Last 90 days"
            end
            option value: "365", selected: (params[:date_range] == "365" ? "selected" : nil) do
              "Last year"
            end
          end
        end

        div class: "filter-row" do
          label "Company:", for: "company_id"
          select name: "company_id", id: "company_id" do
            option value: "", selected: params[:company_id].blank? ? "selected" : nil do
              "All Companies"
            end
            Company.where(deleted_at: nil, active: true).order(:name).each do |company|
              option value: company.id, selected: (params[:company_id] == company.id.to_s ? "selected" : nil) do
                company.name
              end
            end
          end
        end

        div class: "filter-row" do
          input type: "submit", value: "Apply Filters", class: "button"
          link_to "Export CSV", admin_reports_path(params.permit(:date_range, :company_id).merge(format: :csv)),
                  class: "button"
        end
      end
    end

    # Get filter parameters
    date_range = (params[:date_range] || "30").to_i.days.ago
    company_filter = params[:company_id].present? && params[:company_id] != "" ? Company.find(params[:company_id]) : nil

    # Base queries with filters
    base_companies = company_filter ? Company.where(id: company_filter.id) : Company.where(deleted_at: nil)
    base_users = company_filter ? User.where(company_id: company_filter.id) : User.all
    base_sales_orders = company_filter ? SalesOrder.where(company_id: company_filter.id) : SalesOrder.all
    base_user_actions = company_filter ? UserAction.joins(:user).where(users: { company_id: company_filter.id }) : UserAction.all

    # Sales Performance Report
    panel "Sales Performance Report" do
      sales_data = base_sales_orders.where("sales_orders.created_at > ?", date_range)
                                  .joins(:company)
                                  .group("companies.name")
                                  .select('companies.name,
                                         COUNT(*) as orders_count,
                                         SUM(sales_orders.grand_total) as total_revenue')
                                  .order("total_revenue DESC")

      if sales_data.any?
        table_for sales_data do
          column "Company" do |data|
            data.name
          end
          column "Orders Count" do |data|
            data.orders_count
          end
          column "Total Revenue (IDR)" do |data|
            number_with_delimiter(data.total_revenue || 0)
          end
          column "Average Order Value (IDR)" do |data|
            avg = data.orders_count > 0 ? (data.total_revenue || 0) / data.orders_count : 0
            number_with_delimiter(avg.round(2))
          end
        end

        para do
          strong "Total Revenue: "
          span "IDR #{number_with_delimiter(sales_data.sum(&:total_revenue) || 0)}"
        end
        para do
          strong "Total Orders: "
          span "#{sales_data.sum(&:orders_count)}"
        end
      else
        div class: "blank_slate_container" do
          span class: "blank_slate" do
            span "No sales data found for the selected period"
          end
        end
      end
    end

    # User Activity Report
    panel "User Activity Report" do
      activity_data = base_user_actions.where("user_actions.created_at > ?", date_range)
                                     .joins(user: :company)
                                     .group("companies.name, users.name, users.role")
                                     .select('companies.name as company_name,
                                            users.name as user_name,
                                            users.role,
                                            COUNT(*) as total_actions,
                                            COUNT(CASE WHEN success THEN 1 END) as successful_actions,
                                            COUNT(CASE WHEN NOT success THEN 1 END) as failed_actions')
                                     .order("total_actions DESC")
                                     .limit(20)

      if activity_data.any?
        table_for activity_data do
          column "Company" do |data|
            data.company_name
          end
          column "User" do |data|
            data.user_name
          end
          column "Role" do |data|
            status_tag data.role.humanize,
                       class: case data.role
                              when "owner" then "ok"
                              when "manager" then "warning"
                              when "cashier" then "no"
                              end
          end
          column "Total Actions" do |data|
            data.total_actions
          end
          column "Successful" do |data|
            status_tag data.successful_actions, class: "ok"
          end
          column "Failed" do |data|
            data.failed_actions > 0 ? status_tag(data.failed_actions, class: "error") : status_tag("0", class: "ok")
          end
          column "Success Rate" do |data|
            rate = data.total_actions > 0 ? ((data.successful_actions.to_f / data.total_actions) * 100).round(1) : 0
            status_tag "#{rate}%", class: rate > 95 ? "ok" : rate > 80 ? "warning" : "error"
          end
        end
      else
        div class: "blank_slate_container" do
          span class: "blank_slate" do
            span "No user activity found for the selected period"
          end
        end
      end
    end

    # System Health Report
    panel "System Health Report" do
      health_data = {
        companies: {
          total: base_companies.count,
          active: base_companies.where(active: true).count,
          inactive: base_companies.where(active: false).count
        },
        users: {
          total: base_users.where(deleted_at: nil).count,
          active: base_users.where(deleted_at: nil, active: true).count,
          inactive: base_users.where(deleted_at: nil, active: false).count
        },
        sessions: {
          active: UserSession.where("logged_out_at IS NULL AND (expired_at IS NULL OR expired_at > ?)", Time.current).count,
          expired: UserSession.where("expired_at < ?", Time.current).count
        },
        recent_errors: base_user_actions.where("user_actions.created_at > ? AND success = ?", 24.hours.ago, false).count
      }

      columns do
        column do
          table class: "index_table" do
            tbody do
              tr do
                td "Total Companies"
                td health_data[:companies][:total]
              end
              tr do
                td "Active Companies"
                td do
                  status_tag health_data[:companies][:active],
                             class: health_data[:companies][:active] > 0 ? "ok" : "warning"
                end
              end
              tr do
                td "Inactive Companies"
                td do
                  status_tag health_data[:companies][:inactive],
                             class: health_data[:companies][:inactive] == 0 ? "ok" : "warning"
                end
              end
            end
          end
        end
        column do
          table class: "index_table" do
            tbody do
              tr do
                td "Total Users"
                td health_data[:users][:total]
              end
              tr do
                td "Active Users"
                td do
                  status_tag health_data[:users][:active],
                             class: health_data[:users][:active] > 0 ? "ok" : "warning"
                end
              end
              tr do
                td "Inactive Users"
                td do
                  status_tag health_data[:users][:inactive],
                             class: health_data[:users][:inactive] == 0 ? "ok" : "warning"
                end
              end
            end
          end
        end
        column do
          table class: "index_table" do
            tbody do
              tr do
                td "Active Sessions"
                td do
                  status_tag health_data[:sessions][:active],
                             class: health_data[:sessions][:active] > 0 ? "ok" : "no"
                end
              end
              tr do
                td "Expired Sessions"
                td do
                  status_tag health_data[:sessions][:expired],
                             class: health_data[:sessions][:expired] == 0 ? "ok" : "warning"
                end
              end
              tr do
                td "Recent Errors (24h)"
                td do
                  status_tag health_data[:recent_errors],
                             class: health_data[:recent_errors] < 5 ? "ok" :
                                   health_data[:recent_errors] < 20 ? "warning" : "error"
                end
              end
            end
          end
        end
      end
    end

    # Growth Trends Report
    panel "Growth Trends Report" do
      # Daily statistics for the selected period
      daily_stats_query = base_sales_orders.where("sales_orders.created_at > ?", date_range)

      if daily_stats_query.exists?
        daily_stats = daily_stats_query.group("DATE(sales_orders.created_at)")
                                     .select("DATE(sales_orders.created_at) as date,
                                            COUNT(*) as orders_count,
                                            SUM(sales_orders.grand_total) as daily_revenue")
                                     .order("date DESC")
                                     .limit(30)
                                     .to_a
        table_for daily_stats do
          column "Date" do |stat|
            stat.date.strftime("%Y-%m-%d")
          end
          column "Orders" do |stat|
            stat.orders_count
          end
          column "Revenue (IDR)" do |stat|
            number_with_delimiter(stat.daily_revenue || 0)
          end
        end

        # Summary statistics
        total_revenue = daily_stats.map(&:daily_revenue).compact.sum
        total_orders = daily_stats.map(&:orders_count).sum
        stats_count = daily_stats.length
        avg_daily_revenue = stats_count > 0 ? (total_revenue / stats_count) : 0
        avg_daily_orders = stats_count > 0 ? (total_orders.to_f / stats_count) : 0

        para do
          strong "Period Summary:"
        end
        para do
          "Total Revenue: IDR #{number_with_delimiter(total_revenue)} | "
          "Total Orders: #{total_orders} | "
          "Avg Daily Revenue: IDR #{number_with_delimiter(avg_daily_revenue.round(2))} | "
          "Avg Daily Orders: #{avg_daily_orders.round(1)}"
        end
      else
        div class: "blank_slate_container" do
          span class: "blank_slate" do
            span "No growth data found for the selected period"
          end
        end
      end
    end

    # Security Report
    panel "Security Report" do
      security_data = {
        failed_logins: base_user_actions.where("user_actions.created_at > ? AND action = ?", date_range, "login_failure").count,
        successful_logins: base_user_actions.where("user_actions.created_at > ? AND action = ?", date_range, "login_success").count,
        sensitive_actions: base_user_actions.where("user_actions.created_at > ?", date_range)
                                          .where(action: UserAction::SENSITIVE_ACTIONS).count,
        unique_ip_addresses: UserSession.where("user_sessions.created_at > ?", date_range)
                                      .distinct.count(:ip_address)
      }

      columns do
        column do
          table class: "index_table" do
            tbody do
              tr do
                td "Failed Logins"
                td do
                  status_tag security_data[:failed_logins],
                             class: security_data[:failed_logins] < 10 ? "ok" :
                                   security_data[:failed_logins] < 50 ? "warning" : "error"
                end
              end
              tr do
                td "Successful Logins"
                td do
                  status_tag security_data[:successful_logins], class: "ok"
                end
              end
            end
          end
        end
        column do
          table class: "index_table" do
            tbody do
              tr do
                td "Sensitive Actions"
                td do
                  status_tag security_data[:sensitive_actions],
                             class: security_data[:sensitive_actions] > 0 ? "warning" : "ok"
                end
              end
              tr do
                td "Unique IP Addresses"
                td security_data[:unique_ip_addresses]
              end
            end
          end
        end
      end

      # Recent security events
      recent_security_events = base_user_actions.includes(:user)
                                               .where("user_actions.created_at > ?", 7.days.ago)
                                               .where(action: UserAction::SENSITIVE_ACTIONS + [ "login_failure" ])
                                               .order("user_actions.created_at DESC")
                                               .limit(10)

      if recent_security_events.any?
        h4 "Recent Security Events"
        table_for recent_security_events do
          column "User" do |action|
            action.user&.name || "Unknown"
          end
          column "Action" do |action|
            status_tag action.action.humanize,
                       class: action.success? ? "warning" : "error"
          end
          column "IP Address" do |action|
            action.ip_address
          end
          column "Status" do |action|
            status_tag action.success? ? "Success" : "Failed",
                       class: action.success? ? "warning" : "error"
          end
          column "Date" do |action|
            action.created_at.strftime("%Y-%m-%d %H:%M:%S")
          end
        end
      end
    end
  end

  # CSV Export functionality
  page_action :index, method: :get do
    respond_to do |format|
      format.html # Default HTML response
      format.csv do
        date_range = (params[:date_range] || "30").to_i.days.ago
        company_filter = params[:company_id].present? && params[:company_id] != "" ? Company.find(params[:company_id]) : nil

        # Generate CSV data
        csv_data = CSV.generate(headers: true) do |csv|
          # Sales Performance CSV
          csv << [ "Sales Performance Report" ]
          csv << [ "Company", "Orders Count", "Total Revenue (IDR)", "Average Order Value (IDR)" ]

          base_sales_orders = company_filter ? SalesOrder.where(company_id: company_filter.id) : SalesOrder.all
          sales_data = base_sales_orders.where("sales_orders.created_at > ?", date_range)
                                      .joins(:company)
                                      .group("companies.name")
                                      .select('companies.name,
                                             COUNT(*) as orders_count,
                                             SUM(sales_orders.grand_total) as total_revenue')
                                      .order("total_revenue DESC")

          sales_data.each do |data|
            avg_order_value = data.orders_count > 0 ? (data.total_revenue || 0) / data.orders_count : 0
            csv << [ data.name, data.orders_count, data.total_revenue || 0, avg_order_value.round(2) ]
          end

          csv << []
          csv << [ "User Activity Report" ]
          csv << [ "Company", "User", "Role", "Total Actions", "Successful Actions", "Failed Actions", "Success Rate %" ]

          base_user_actions = company_filter ? UserAction.joins(:user).where(users: { company_id: company_filter.id }) : UserAction.all
          activity_data = base_user_actions.where("user_actions.created_at > ?", date_range)
                                         .joins(user: :company)
                                         .group("companies.name, users.name, users.role")
                                         .select('companies.name as company_name,
                                                users.name as user_name,
                                                users.role,
                                                COUNT(*) as total_actions,
                                                COUNT(CASE WHEN success THEN 1 END) as successful_actions,
                                                COUNT(CASE WHEN NOT success THEN 1 END) as failed_actions')
                                         .order("total_actions DESC")

          activity_data.each do |data|
            success_rate = data.total_actions > 0 ? ((data.successful_actions.to_f / data.total_actions) * 100).round(1) : 0
            csv << [ data.company_name, data.user_name, data.role, data.total_actions, data.successful_actions, data.failed_actions, success_rate ]
          end
        end

        send_data csv_data,
                  filename: "pos_reports_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: "text/csv",
                  disposition: "attachment"
      end
    end
  end
end
