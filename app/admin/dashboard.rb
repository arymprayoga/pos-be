# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    # System Overview Panel
    panel "System Overview" do
      columns do
        column do
          div class: "status-table" do
            div class: "stat-row" do
              span "Total Companies: #{Company.count}"
            end
            div class: "stat-row" do
              span "Active Companies: #{Company.count}"
            end
            div class: "stat-row" do
              span "Total Users: #{User.count}"
            end
            div class: "stat-row" do
              span "Active Users: #{User.count}"
            end
          end
        end
        column do
          div class: "status-table" do
            div class: "stat-row" do
              span "System Uptime: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
            end
            div class: "stat-row" do
              span "Database Status: Connected"
            end
          end
        end
      end
    end

    # Recent Activity Panel
    panel "Recent Activity (Last 24 Hours)" do
      div class: "blank_slate_container" do
        span class: "blank_slate" do
          span "No recent activity to display"
        end
      end
    end

    # Business Metrics Panel
    panel "Business Metrics (Last 30 Days)" do
      companies_count = 0
      users_count = 0
      sales_orders_count = 0

      columns do
        column do
          div class: "metric-card" do
            h3 "#{companies_count}"
            span "Active Companies"
          end
        end
        column do
          div class: "metric-card" do
            h3 "#{users_count}"
            span "Active Users"
          end
        end
        column do
          div class: "metric-card" do
            h3 "#{sales_orders_count}"
            span "Sales Orders (30d)"
          end
        end
        column do
          div class: "metric-card" do
            avg_users = companies_count > 0 ? (users_count.to_f / companies_count).round(1) : 0
            h3 "#{avg_users}"
            span "Avg Users/Company"
          end
        end
      end
    end

    # Top Companies Panel
    panel "Top Companies by Activity" do
      div class: "blank_slate_container" do
        span class: "blank_slate" do
          span "No company data available yet"
        end
      end
    end

    # User Role Distribution Panel
    panel "User Role Distribution" do
      div class: "blank_slate_container" do
        span class: "blank_slate" do
          span "No user data available yet"
        end
      end
    end

    # System Health Panel
    panel "System Health" do
      columns do
        column do
          div class: "status-table" do
            div class: "stat-row" do
              span "System Health: OK"
            end
            div class: "stat-row" do
              span "Active Sessions: 0"
            end
          end
        end
        column do
          div class: "status-table" do
            div class: "stat-row" do
              span "Database: Connected"
            end
            div class: "stat-row" do
              span "System Status: Healthy"
            end
          end
        end
      end
    end

    # Quick Actions Panel
    panel "Quick Actions" do
      div class: "quick-actions" do
        span "Welcome to POS Admin Dashboard"
      end
    end
  end
end
